# Azure Onboarding Scripts

## Azure Function App Storage Account Discovery

### Overview

This script helps identify which Azure Storage Accounts are used by your Function Apps. This is useful when you want to
limit the scope of the `Storage Blob Data Reader` role assignment for Upwind CloudScanner instead of granting it to all
resources in your management group or subscription.

### Why This Matters

By default, Upwind CloudScanner needs `Storage Blob Data Reader` access to scan Function App code (which is stored in
Azure Storage Blobs). However, some customers prefer to limit this access to only the storage accounts that actually
contain Function App code, rather than granting it broadly.

### Prerequisites

- Azure CLI installed and configured
- Appropriate permissions to:
  - List Function Apps
  - Read Function App configuration
  - List Storage Accounts

### Usage

#### Basic Usage

```bash
./list-function-storage-accounts.sh
```

The script will prompt you to select a scope:

1. **Current subscription only** - Scans only your currently selected subscription
2. **All accessible subscriptions** - Scans all subscriptions you have access to
3. **Specific management group** - Scans all subscriptions within a management group

### Output

The script provides:

1. **Console output** showing all discovered Function Apps and their storage accounts
2. **Terraform variable** configuration ready to copy/paste
3. **Azure CLI commands** for manual role assignment
4. **Text file** with the list of storage account resource IDs

### Example Output

```txt
================================================
Function App Storage Account Discovery
================================================

Current Subscription: Production (12345678-1234-1234-1234-123456789012)

Select scope for discovery:
1) Current subscription only
2) All accessible subscriptions
3) Specific management group
Enter choice (1-3): 1

Scanning for Function Apps and their storage accounts...

Checking subscription: Production (12345678-1234-1234-1234-123456789012)
  Found 3 Function App(s)
    ✓ my-function-app → myfuncsa123
    ✓ api-function → apifuncsa456
    ✓ worker-function → workerfuncsa789

================================================
Summary
================================================

Total Function Apps found: 3
Unique Storage Accounts: 3

Storage Account Resource IDs:

  /subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-functions/providers/Microsoft.Storage/storageAccounts/myfuncsa123
  /subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-functions/providers/Microsoft.Storage/storageAccounts/apifuncsa456
  /subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-functions/providers/Microsoft.Storage/storageAccounts/workerfuncsa789
```

### Using the Results with Terraform

#### Option 1: Provide Storage Account List (Recommended for Security-Conscious Customers)

After running the script, add the discovered storage accounts to your Terraform configuration:

```hcl
module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # ... other configuration ...

  # Limit Storage Blob Data Reader to specific storage accounts only
  # This grants the least privilege - only the storage accounts that contain Function App code
  function_storage_accounts = [
    "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-functions/providers/Microsoft.Storage/storageAccounts/myfuncsa123",
    "/subscriptions/12345678-1234-1234-1234-123456789012/resourceGroups/rg-functions/providers/Microsoft.Storage/storageAccounts/apifuncsa456",
  ]
}
```

**Benefits:**

- ✅ Least privilege access - only specific storage accounts
- ✅ Meets strict security requirements
- ✅ Clear audit trail of what has access

**Trade-offs:**

- ⚠️ Requires running the discovery script
- ⚠️ Must be updated when Function Apps are added/removed
- ⚠️ New Function Apps won't be scanned until the list is updated

#### Option 2: Disable Function Scanning (If Not Needed)

If you don't need to scan Function Apps at all:

```hcl
module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # ... other configuration ...

  # Disable function scanning entirely
  disable_function_scanning = true
}
```

#### Option 3: Broad Access (Default Behavior)

If you're comfortable with broader access, the default behavior grants `Storage Blob Data Reader` to all resources in scope:

```hcl
module "upwind_integration_azure_onboarding" {
  source = "upwindsecurity/onboarding/azurerm//modules/tenant"

  # ... other configuration ...

  # No additional configuration needed - default behavior
}
```

### Troubleshooting

#### No Function Apps Found

If the script reports no Function Apps:

- Verify you're scanning the correct subscriptions/management group
- Ensure you have permissions to list Function Apps
- Check if Function Apps exist in the selected scope

#### Storage Account Not Found

If a Function App's storage account cannot be found:

- The storage account might be in a different subscription not included in the scan
- The Function App might use a managed identity instead of a connection string
- The storage account might have been deleted but the Function App still references it

#### Permission Errors

If you encounter permission errors:

- Ensure you have at least `Reader` role on the subscriptions being scanned
- For management group scans, you need `Reader` at the management group level

### Security Considerations

**Least Privilege Approach:**

- Use the discovered storage account list to limit access to only what's necessary
- Regularly re-run this script as you add/remove Function Apps
- Consider automating this discovery as part of your CI/CD pipeline

**Broad Access Trade-offs:**

- Simpler to manage (no need to maintain a list)
- Automatically covers new Function Apps
- Grants more access than strictly necessary

### Automation

You can automate this script in your CI/CD pipeline:

```bash
# Run in non-interactive mode by piping choice
echo "2" | ./list-function-storage-accounts.sh > storage-accounts.txt

# Parse the output for Terraform
grep "^  /subscriptions/" storage-accounts.txt > terraform-storage-list.txt
```

### Support

For issues or questions:

- Open an issue in the repository
- Contact Upwind support

## Cleanup Role Assignments

This script helps clean up role assignments for a specific service principal. This is useful when you have lost the
Terraform state of an older Upwind onboarding and need to clean up the role assignments manually.

### Usage

```bash
./cleanup-role-assignments.sh --client-id 12345678-1234-1234-1234-123456789abc --orchestrator-subscription-id <sub-id>
```

#### Options

- `--client-id`: Azure AD application client ID (required)
- `--orchestrator-subscription-id`: Azure orchestrator subscription ID (optional)
- `--management-group-ids`: Comma-separated list of management group IDs (optional)
- `--dry-run`: List resources without deleting them
