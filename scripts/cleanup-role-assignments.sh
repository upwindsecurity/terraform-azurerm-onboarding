#!/bin/bash
# Note: We don't use 'set -e' here because we want to continue even if some
# role assignment deletions fail (e.g., when they're inherited from higher scopes)
# Example usage:
# ./cleanup-role-assignments.sh --client-id 12345678-1234-1234-1234-123456789abc --orchestrator-subscription-id <sub-id>
set -o pipefail

# Default values
CLIENT_ID=""
TENANT_ID=""
ORCHESTRATOR_SUBSCRIPTION_ID=""
MANAGEMENT_GROUP_IDS=""
DRY_RUN=false

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --client-id <id>             Azure AD application client ID (required)"
    echo "  --orchestrator-subscription-id <id>       Azure orchestrator subscription ID (optional)"
    echo "  --management-group-ids <ids> Comma-separated list of management group IDs (optional)"
    echo "                               If not provided, defaults to tenant root management group"
    echo "  --dry-run                    List resources without deleting them"
    echo "  --help                       Display this help message"
    echo ""
    echo "Description:"
    echo "  This script cleans up role assignments for a specific service principal."
    echo "  It will:"
    echo "    1. Look up the service principal by client ID"
    echo "    2. Find and delete role assignments at management group level(s)"
    echo "    3. Find and delete role assignments at orchestrator subscription level (if provided)"
    echo ""
    echo "Examples:"
    echo "  # Dry run to see what would be deleted"
    echo "  $0 --client-id 12345678-1234-1234-1234-123456789abc --dry-run"
    echo ""
    echo "  # Delete role assignments"
    echo "  $0 --client-id 12345678-1234-1234-1234-123456789abc"
    echo ""
    echo "  # Include subscription-level cleanup"
    echo "  $0 --client-id 12345678-1234-1234-1234-123456789abc --orchestrator-subscription-id <sub-id>"
    echo ""
    echo "  # Cleanup at specific management groups"
    echo "  $0 --client-id 12345678-1234-1234-1234-123456789abc --management-group-ids mg1,mg2,mg3"
    echo ""
    echo "  # Cleanup at management groups and subscription"
    echo "  $0 --client-id 12345678-1234-1234-1234-123456789abc \\"
    echo "     --management-group-ids mg1,mg2 --orchestrator-subscription-id <sub-id>"
    exit 1
}

# Parse command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        --client-id) CLIENT_ID="$2"; shift 2 ;;
        --orchestrator-subscription-id) ORCHESTRATOR_SUBSCRIPTION_ID="$2"; shift 2 ;;
        --management-group-ids) MANAGEMENT_GROUP_IDS="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help) usage ;;
        *) echo "Unknown parameter: $1"; usage ;;
    esac
done

# Validate required inputs
if [ -z "$CLIENT_ID" ]; then
    echo "Error: Missing required parameter --client-id"
    usage
fi

# Login and get tenant ID
echo "Checking Azure login status..."
az account show > /dev/null 2>&1 || az login

TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Using Azure AD tenant: $TENANT_ID"

# Look up service principal by client ID
echo "Looking up service principal with client ID: $CLIENT_ID..."
SP_ID=$(az ad sp list --filter "appId eq '$CLIENT_ID'" --query '[0].id' -o tsv)

if [ -z "$SP_ID" ]; then
    echo "Error: No service principal found with client ID: $CLIENT_ID"
    exit 1
fi

echo "Found service principal with object ID: $SP_ID"

# Get the display name for reference
SP_NAME=$(az ad sp show --id "$SP_ID" --query displayName -o tsv)
echo "Service principal display name: $SP_NAME"

if $DRY_RUN; then
    echo ""
    echo "=========================================="
    echo "DRY RUN MODE - No resources will be deleted"
    echo "=========================================="
    echo ""
fi

# Function to clean up role assignments at a given scope
cleanup_role_assignments() {
    local scope=$1
    local scope_name=$2

    echo ""
    echo "=========================================="
    echo "Cleaning up role assignments at $scope_name"
    echo "Scope: $scope"
    echo "=========================================="

    # Find all role assignments for this service principal at this scope
    echo "Finding role assignments for service principal..."
    local assignments
    assignments=$(az role assignment list --scope "$scope" \
        --query "[?principalId=='$SP_ID'].{id:id, role:roleDefinitionName, scope:scope}" -o json)

    local assignment_count=$(echo "$assignments" | jq 'length')

    if [ "$assignment_count" -eq 0 ]; then
        echo "No role assignments found for this service principal at $scope_name"
    else
        echo "Found $assignment_count role assignment(s):"
        echo "$assignments" | jq -r '.[] | "  - Role: \(.role)\n    ID: \(.id)"'

        if ! $DRY_RUN; then
            echo ""
            echo "Deleting role assignments..."
            local deleted_count=0
            local failed_count=0

            echo "$assignments" | jq -r '.[].id' | while read -r assignment_id; do
                echo "  Deleting: $assignment_id"
                if az role assignment delete --ids "$assignment_id" 2>/dev/null; then
                    ((deleted_count++)) || true
                else
                    echo "    Warning: Failed to delete (may be inherited from higher scope)"
                    ((failed_count++)) || true
                fi
            done

            echo "Attempted to delete $assignment_count role assignment(s)"
            if [ $failed_count -gt 0 ]; then
                echo "Note: $failed_count assignment(s) could not be deleted (likely inherited from higher scope)"
            fi
        fi
    fi
}

# Clean up at management group level(s)
# If no management groups specified, default to tenant root
if [ -z "$MANAGEMENT_GROUP_IDS" ]; then
    MANAGEMENT_GROUP_IDS="$TENANT_ID"
    echo ""
    echo "=========================================="
    echo "TENANT ROOT MANAGEMENT GROUP CLEANUP"
    echo "=========================================="
    echo "No management groups specified, defaulting to tenant root"
else
    echo ""
    echo "=========================================="
    echo "MANAGEMENT GROUP CLEANUP"
    echo "=========================================="
fi

# Convert comma-separated list to array
IFS=',' read -ra MG_ARRAY <<< "$MANAGEMENT_GROUP_IDS"

# Clean up each management group
for MG_ID in "${MG_ARRAY[@]}"; do
    # Trim whitespace
    MG_ID=$(echo "$MG_ID" | xargs)

    if [ -n "$MG_ID" ]; then
        MG_SCOPE="/providers/Microsoft.Management/managementGroups/$MG_ID"
        cleanup_role_assignments "$MG_SCOPE" "management group '$MG_ID'"
    fi
done

# Clean up at subscription level if provided
if [ -n "$ORCHESTRATOR_SUBSCRIPTION_ID" ]; then
    echo ""
    echo "=========================================="
    echo "SUBSCRIPTION CLEANUP"
    echo "=========================================="

    SUBSCRIPTION_SCOPE="/subscriptions/$ORCHESTRATOR_SUBSCRIPTION_ID"
    cleanup_role_assignments "$SUBSCRIPTION_SCOPE" "subscription"
fi

# Summary
echo ""
echo "=========================================="
echo "CLEANUP SUMMARY"
echo "=========================================="
echo "Service Principal: $SP_NAME"
echo "Client ID: $CLIENT_ID"
echo "Object ID: $SP_ID"
echo "Tenant ID: $TENANT_ID"
echo "Management Group(s): $MANAGEMENT_GROUP_IDS"
if [ -n "$ORCHESTRATOR_SUBSCRIPTION_ID" ]; then
    echo "Subscription ID: $ORCHESTRATOR_SUBSCRIPTION_ID"
fi

if $DRY_RUN; then
    echo ""
    echo "DRY RUN COMPLETED - No resources were deleted"
    echo "Run without --dry-run to actually delete the resources"
else
    echo ""
    echo "CLEANUP COMPLETED SUCCESSFULLY"
    echo ""
    echo "Note: This script only cleaned up role assignments for the specified service principal."
    echo "Custom roles were NOT deleted."
fi
