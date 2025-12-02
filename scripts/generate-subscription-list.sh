#!/bin/bash

# Script to generate an inclusive list of subscription IDs from a management group,
# excluding specified subscriptions. This is useful for creating cloudapi_include_subscriptions
# or cloudscanner_include_subscriptions lists when you want to use a management group
# as the base scope but exclude certain subscriptions.
#
# Usage: ./generate-subscription-list.sh <management-group-id> [excluded-sub-id-1] [excluded-sub-id-2] ...
#
# Example:
#   ./generate-subscription-list.sh upwindsecurity-labs 32d156f8-2595-4e77-9710-4f9ea4e6be8d
#
# Output formats:
#   - Terraform list format (default)
#   - JSON array (with --json flag)
#   - Plain text, one per line (with --plain flag)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS] <management-group-id> [excluded-subscription-ids...]"
    echo ""
    echo "Options:"
    echo "  --json              Output as JSON array"
    echo "  --plain             Output as plain text (one per line)"
    echo "  --terraform         Output as Terraform list (default)"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Arguments:"
    echo "  management-group-id         The management group ID to query"
    echo "  excluded-subscription-ids   Optional subscription IDs to exclude"
    echo ""
    echo "Example:"
    echo "  $0 upwindsecurity-labs 32d156f8-2595-4e77-9710-4f9ea4e6be8d"
    exit 1
}

# Parse options
OUTPUT_FORMAT="terraform"
while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --plain)
            OUTPUT_FORMAT="plain"
            shift
            ;;
        --terraform)
            OUTPUT_FORMAT="terraform"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            break
            ;;
    esac
done

# Check if management group ID is provided
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Management group ID is required${NC}" >&2
    usage
fi

MANAGEMENT_GROUP_ID="$1"
shift

# Remaining arguments are excluded subscription IDs
EXCLUDED_SUBS=("$@")

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed${NC}" >&2
    echo "Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli" >&2
    exit 1
fi

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    echo -e "${RED}Error: Not logged in to Azure${NC}" >&2
    echo "Please run: az login" >&2
    exit 1
fi

get_child_management_groups() {
    local mg_id="$1"
    az account management-group show \
        --name "$mg_id" \
        --expand \
        --query "children[?type=='/providers/Microsoft.Management/managementGroups'].name" \
        --output tsv 2>/dev/null || true
}

echo -e "${YELLOW}Querying subscriptions under management group hierarchy rooted at: ${MANAGEMENT_GROUP_ID}${NC}" >&2

MG_QUEUE=("$MANAGEMENT_GROUP_ID")
ALL_MGS=()

while [ ${#MG_QUEUE[@]} -gt 0 ]; do
    current_mg="${MG_QUEUE[0]}"
    MG_QUEUE=("${MG_QUEUE[@]:1}")
    ALL_MGS+=("$current_mg")

    children_output=$(get_child_management_groups "$current_mg")
    while IFS= read -r child; do
        if [ -n "$child" ]; then
            MG_QUEUE+=("$child")
        fi
    done <<EOF
$children_output
EOF
done

SUBSCRIPTIONS=""
for mg in "${ALL_MGS[@]}"; do
    result=$(az account management-group subscription show-sub-under-mg \
        --name "$mg" \
        --query "[].id" \
        --output tsv 2>/dev/null || true)
    if [ -n "$result" ]; then
        if [ -z "$SUBSCRIPTIONS" ]; then
            SUBSCRIPTIONS="$result"
        else
            SUBSCRIPTIONS+=$'\n'$result
        fi
    fi
done

if [ -z "$SUBSCRIPTIONS" ]; then
    echo -e "${RED}Error: No subscriptions found under management group '${MANAGEMENT_GROUP_ID}'${NC}" >&2
    echo "Please verify the management group ID and your permissions." >&2
    exit 1
fi

# Extract subscription IDs from the full resource IDs
# Format: /subscriptions/{subscription-id}
SUBSCRIPTION_IDS=()
while IFS= read -r line; do
    if [[ $line =~ /subscriptions/([a-f0-9-]+) ]]; then
        SUBSCRIPTION_IDS+=("${BASH_REMATCH[1]}")
    fi
done <<< "$SUBSCRIPTIONS"

echo -e "${GREEN}Found ${#SUBSCRIPTION_IDS[@]} subscription(s) under management group${NC}" >&2

# Filter out excluded subscriptions
FILTERED_SUBS=()
for sub_id in "${SUBSCRIPTION_IDS[@]}"; do
    excluded=false
    for excluded_sub in "${EXCLUDED_SUBS[@]}"; do
        if [ "$sub_id" == "$excluded_sub" ]; then
            excluded=true
            echo -e "${YELLOW}Excluding subscription: ${sub_id}${NC}" >&2
            break
        fi
    done
    if [ "$excluded" = false ]; then
        FILTERED_SUBS+=("$sub_id")
    fi
done

if [ ${#FILTERED_SUBS[@]} -eq 0 ]; then
    echo -e "${RED}Error: No subscriptions remaining after exclusions${NC}" >&2
    exit 1
fi

echo -e "${GREEN}Result: ${#FILTERED_SUBS[@]} subscription(s) after exclusions${NC}" >&2
echo "" >&2

# Output in requested format
case $OUTPUT_FORMAT in
    json)
        # JSON array format
        printf '['
        for i in "${!FILTERED_SUBS[@]}"; do
            printf '"%s"' "${FILTERED_SUBS[$i]}"
            if [ $i -lt $((${#FILTERED_SUBS[@]} - 1)) ]; then
                printf ','
            fi
        done
        printf ']\n'
        ;;
    plain)
        # Plain text, one per line
        printf '%s\n' "${FILTERED_SUBS[@]}"
        ;;
    terraform)
        # Terraform list format
        printf '['
        for i in "${!FILTERED_SUBS[@]}"; do
            printf '"%s"' "${FILTERED_SUBS[$i]}"
            if [ $i -lt $((${#FILTERED_SUBS[@]} - 1)) ]; then
                printf ', '
            fi
        done
        printf ']\n'
        ;;
esac
