#!/bin/bash

# Script to identify storage accounts used by Azure Function Apps
# This helps determine which storage accounts need "Storage Blob Data Reader" access
# for Upwind CloudScanner to scan Function App code

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Function App Storage Account Discovery${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}"
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
fi

# Check if logged in
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo "Please run: az login"
    exit 1
fi

# Get current subscription
CURRENT_SUB=$(az account show --query id -o tsv)
CURRENT_SUB_NAME=$(az account show --query name -o tsv)

echo -e "${GREEN}Current Subscription:${NC} $CURRENT_SUB_NAME ($CURRENT_SUB)"
echo ""

# Allow user to specify scope
echo "Select scope for discovery:"
echo "1) Current subscription only"
echo "2) All accessible subscriptions"
echo "3) Specific management group"
read -p "Enter choice (1-3): " SCOPE_CHOICE

SUBSCRIPTIONS=()

case $SCOPE_CHOICE in
    1)
        SUBSCRIPTIONS=("$CURRENT_SUB")
        ;;
    2)
        echo -e "${YELLOW}Fetching all accessible subscriptions...${NC}"
        while IFS= read -r sub; do
            SUBSCRIPTIONS+=("$sub")
        done < <(az account list --query "[].id" -o tsv)
        echo -e "${GREEN}Found ${#SUBSCRIPTIONS[@]} subscriptions${NC}"
        ;;
    3)
        read -p "Enter management group ID: " MG_ID
        echo -e "${YELLOW}Fetching subscriptions in management group $MG_ID...${NC}"
        while IFS= read -r sub; do
            SUBSCRIPTIONS+=("$sub")
        done < <(az account management-group show --name "$MG_ID" --expand --recurse --query "children[?type=='Microsoft.Management/managementGroups/subscriptions'].name" -o tsv)
        if [ ${#SUBSCRIPTIONS[@]} -eq 0 ]; then
            echo -e "${RED}No subscriptions found in management group${NC}"
            exit 1
        fi
        echo -e "${GREEN}Found ${#SUBSCRIPTIONS[@]} subscriptions${NC}"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}Scanning for Function Apps and their storage accounts...${NC}"
echo ""

# Simple arrays to store results (bash 3.2 compatible)
STORAGE_ACCOUNTS=()  # Will store unique storage account resource IDs
TOTAL_FUNCTION_APPS=0

# Iterate through subscriptions
for SUB_ID in "${SUBSCRIPTIONS[@]}"; do
    SUB_NAME=$(az account show --subscription "$SUB_ID" --query name -o tsv 2>/dev/null || echo "Unknown")

    echo -e "${BLUE}Checking subscription: ${NC}$SUB_NAME ($SUB_ID)"

    # Get all function apps in the subscription
    FUNCTION_APP_LIST=$(az functionapp list --subscription "$SUB_ID" --query "[].{name:name, resourceGroup:resourceGroup, id:id}" -o json 2>/dev/null || echo "[]")

    FUNCTION_APP_COUNT=$(echo "$FUNCTION_APP_LIST" | jq -r '. | length')

    if [ "$FUNCTION_APP_COUNT" -eq 0 ]; then
        echo -e "  ${YELLOW}No Function Apps found${NC}"
        continue
    fi

    echo -e "  ${GREEN}Found $FUNCTION_APP_COUNT Function App(s)${NC}"
    TOTAL_FUNCTION_APPS=$((TOTAL_FUNCTION_APPS + FUNCTION_APP_COUNT))

    # Process each function app - avoid subshell to preserve array modifications
    FUNCTION_APP_INDICES=$(echo "$FUNCTION_APP_LIST" | jq -r 'to_entries | .[] | .key')

    for INDEX in $FUNCTION_APP_INDICES; do
        FUNCTION_APP_NAME=$(echo "$FUNCTION_APP_LIST" | jq -r ".[$INDEX].name")
        FUNCTION_APP_RG=$(echo "$FUNCTION_APP_LIST" | jq -r ".[$INDEX].resourceGroup")
        FUNCTION_APP_ID=$(echo "$FUNCTION_APP_LIST" | jq -r ".[$INDEX].id")

        STORAGE_ACCOUNT_NAME=""

        # Method 1: Try to get from functionAppConfig.deployment.storage.value (newer flex consumption model - blob URL)
        FUNCTION_APP_CONFIG=$(az functionapp show \
            --name "$FUNCTION_APP_NAME" \
            --resource-group "$FUNCTION_APP_RG" \
            --subscription "$SUB_ID" \
            --query "properties.functionAppConfig.deployment.storage.value" \
            -o tsv 2>/dev/null || echo "")

        if [ -n "$FUNCTION_APP_CONFIG" ] && [ "$FUNCTION_APP_CONFIG" != "null" ]; then
            # Extract storage account name from blob URL
            # Format: https://<storage-account>.blob.core.windows.net/...
            STORAGE_ACCOUNT_NAME=$(echo "$FUNCTION_APP_CONFIG" | sed -n 's|https://\([^.]*\)\.blob\.core\.windows\.net.*|\1|p')
        fi

        # Method 2: Try to get from functionAppConfig.deployment.storage.authentication.storageAccountConnectionStringName
        if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
            CONNECTION_STRING_NAME=$(az functionapp show \
                --name "$FUNCTION_APP_NAME" \
                --resource-group "$FUNCTION_APP_RG" \
                --subscription "$SUB_ID" \
                --query "properties.functionAppConfig.deployment.storage.authentication.storageAccountConnectionStringName" \
                -o tsv 2>/dev/null || echo "")

            if [ -n "$CONNECTION_STRING_NAME" ] && [ "$CONNECTION_STRING_NAME" != "null" ]; then
                # Get the connection string from app settings
                STORAGE_CONNECTION=$(az functionapp config appsettings list \
                    --name "$FUNCTION_APP_NAME" \
                    --resource-group "$FUNCTION_APP_RG" \
                    --subscription "$SUB_ID" \
                    --query "[?name=='$CONNECTION_STRING_NAME'].value" \
                    -o tsv 2>/dev/null || echo "")

                if [ -n "$STORAGE_CONNECTION" ]; then
                    # Extract storage account name from connection string
                    STORAGE_ACCOUNT_NAME=$(echo "$STORAGE_CONNECTION" | sed -n 's/.*AccountName=\([^;]*\).*/\1/p')

                    # Try alternative format (resource ID)
                    if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
                        if [[ "$STORAGE_CONNECTION" =~ /subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft.Storage/storageAccounts/([^/]+) ]]; then
                            STORAGE_ACCOUNT_NAME="${BASH_REMATCH[3]}"
                        fi
                    fi
                fi
            fi
        fi

        # Method 3: Try traditional AzureWebJobsStorage app setting
        if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
            STORAGE_CONNECTION=$(az functionapp config appsettings list \
                --name "$FUNCTION_APP_NAME" \
                --resource-group "$FUNCTION_APP_RG" \
                --subscription "$SUB_ID" \
                --query "[?name=='AzureWebJobsStorage'].value" \
                -o tsv 2>/dev/null || echo "")

            if [ -n "$STORAGE_CONNECTION" ]; then
                # Extract storage account name from connection string
                # Format: DefaultEndpointsProtocol=https;AccountName=<name>;...
                STORAGE_ACCOUNT_NAME=$(echo "$STORAGE_CONNECTION" | sed -n 's/.*AccountName=\([^;]*\).*/\1/p')

                # Try alternative format (resource ID)
                if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
                    if [[ "$STORAGE_CONNECTION" =~ /subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft.Storage/storageAccounts/([^/]+) ]]; then
                        STORAGE_ACCOUNT_NAME="${BASH_REMATCH[3]}"
                    fi
                fi
            fi
        fi

        if [ -z "$STORAGE_ACCOUNT_NAME" ]; then
            echo -e "    ${YELLOW}⚠ $FUNCTION_APP_NAME: No storage account configured${NC}"
            continue
        fi

        # Get the full resource ID of the storage account
        STORAGE_ACCOUNT_ID=$(az storage account list \
            --subscription "$SUB_ID" \
            --query "[?name=='$STORAGE_ACCOUNT_NAME'].id" \
            -o tsv 2>/dev/null | head -n 1)

        if [ -z "$STORAGE_ACCOUNT_ID" ]; then
            # Try to find in other subscriptions if not found
            for OTHER_SUB in "${SUBSCRIPTIONS[@]}"; do
                STORAGE_ACCOUNT_ID=$(az storage account list \
                    --subscription "$OTHER_SUB" \
                    --query "[?name=='$STORAGE_ACCOUNT_NAME'].id" \
                    -o tsv 2>/dev/null | head -n 1)
                if [ -n "$STORAGE_ACCOUNT_ID" ]; then
                    break
                fi
            done
        fi

        if [ -n "$STORAGE_ACCOUNT_ID" ]; then
            echo -e "    ${GREEN}✓ $FUNCTION_APP_NAME → $STORAGE_ACCOUNT_NAME${NC}"

            # Check if storage account is already in the array (avoid duplicates)
            ALREADY_EXISTS=0
            for existing in "${STORAGE_ACCOUNTS[@]}"; do
                if [ "$existing" = "$STORAGE_ACCOUNT_ID" ]; then
                    ALREADY_EXISTS=1
                    break
                fi
            done

            if [ $ALREADY_EXISTS -eq 0 ]; then
                STORAGE_ACCOUNTS+=("$STORAGE_ACCOUNT_ID")
            fi
        else
            echo -e "    ${RED}✗ $FUNCTION_APP_NAME: Storage account '$STORAGE_ACCOUNT_NAME' not found${NC}"
        fi
    done
done

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo -e "${GREEN}Total Function Apps found: $TOTAL_FUNCTION_APPS${NC}"
echo -e "${GREEN}Unique Storage Accounts: ${#STORAGE_ACCOUNTS[@]}${NC}"
echo ""

if [ ${#STORAGE_ACCOUNTS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No storage accounts found. This could mean:${NC}"
    echo -e "${YELLOW}  - No Function Apps are deployed${NC}"
    echo -e "${YELLOW}  - Function Apps use managed identities instead of connection strings${NC}"
    echo -e "${YELLOW}  - Storage accounts are in different subscriptions not included in scan${NC}"
    exit 0
fi

echo -e "${BLUE}Storage Account Resource IDs:${NC}"
echo ""
for STORAGE_ID in "${STORAGE_ACCOUNTS[@]}"; do
    echo "  $STORAGE_ID"
done

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Terraform Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Add this to your Terraform configuration:"
echo ""
echo -e "${GREEN}variable \"function_storage_accounts\" {${NC}"
echo -e "${GREEN}  description = \"List of storage account resource IDs used by Function Apps for code storage\"${NC}"
echo -e "${GREEN}  type        = list(string)${NC}"
echo -e "${GREEN}  default     = [${NC}"
for STORAGE_ID in "${STORAGE_ACCOUNTS[@]}"; do
    echo -e "${GREEN}    \"$STORAGE_ID\",${NC}"
done
echo -e "${GREEN}  ]${NC}"
echo -e "${GREEN}}${NC}"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Azure CLI Commands${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "To manually grant Storage Blob Data Reader access:"
echo ""
for STORAGE_ID in "${STORAGE_ACCOUNTS[@]}"; do
    echo "az role assignment create \\"
    echo "  --role \"Storage Blob Data Reader\" \\"
    echo "  --assignee-object-id <CLOUDSCANNER_IDENTITY_PRINCIPAL_ID> \\"
    echo "  --scope \"$STORAGE_ID\""
    echo ""
done

# Save to file
OUTPUT_FILE="function-storage-accounts-$(date +%Y%m%d-%H%M%S).txt"
{
    echo "# Function App Storage Accounts"
    echo "# Generated: $(date)"
    echo ""
    echo "# Storage Account Resource IDs:"
    for STORAGE_ID in "${STORAGE_ACCOUNTS[@]}"; do
        echo "$STORAGE_ID"
    done
} > "$OUTPUT_FILE"

echo -e "${GREEN}Results saved to: $OUTPUT_FILE${NC}"
