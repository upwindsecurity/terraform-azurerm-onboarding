# region upwind

variable "upwind_organization_id" {
  description = "The identifier of the Upwind organization to integrate with."
  type        = string
}

variable "upwind_client_id" {
  description = "The client ID used for authentication with the Upwind Authorization Service. Required for legacy client-secret onboarding; not used when saas_enabled or use_workload_identity_federation is true (both are secretless and make no Upwind API call)."
  type        = string
  default     = ""

  validation {
    condition     = var.saas_enabled || var.use_workload_identity_federation || var.upwind_client_id != ""
    error_message = "upwind_client_id must be provided and cannot be empty for legacy client-secret onboarding (not required when saas_enabled or use_workload_identity_federation is true)."
  }
}

variable "upwind_client_secret" {
  description = "The client secret for authentication with the Upwind Authorization Service. Required for legacy client-secret onboarding; not used when saas_enabled or use_workload_identity_federation is true."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.saas_enabled || var.use_workload_identity_federation || var.upwind_client_secret != ""
    error_message = "upwind_client_secret must be provided and cannot be empty for legacy client-secret onboarding (not required when saas_enabled or use_workload_identity_federation is true)."
  }
}

variable "scanner_client_id" {
  description = "The client ID used for authentication with the Upwind CloudScanner Service."
  type        = string
  default     = ""
}

variable "scanner_client_secret" {
  description = "The client secret for authentication with the Upwind CloudScanner Service."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.scanner_client_id == "" || var.scanner_client_secret != ""
    error_message = "scanner_client_secret must be provided and non-empty when scanner_client_id is specified."
  }
}

variable "upwind_auth_endpoint" {
  description = "The Authentication API endpoint."
  type        = string
  default     = "https://auth.upwind.io"
}

variable "upwind_integration_endpoint" {
  description = "The Integration API endpoint."
  type        = string
  default     = "https://integration.upwind.io"
}

variable "upwind_region" {
  description = "The region where the Upwind components will be deployed. Must be 'us', 'eu', 'ap' or 'me'"
  type        = string
  default     = "us"

  validation {
    condition     = var.upwind_region == "us" || var.upwind_region == "eu" || var.upwind_region == "me" || var.upwind_region == "pdc01" || var.upwind_region == "ap"
    error_message = "upwind_region must be either 'us', 'eu', 'ap' or 'me'."
  }
}

# endregion upwind

# region azure

variable "azure_tenant_id" {
  description = "The Azure Tenant that will be onboarded to the Upwind organization."
  type        = string
  default     = ""
}

variable "azure_management_group_ids" {
  description = "List of management group names (not full resource IDs) to grant read access to. For example, use 'upwindsecurity-sandbox' instead of '/providers/Microsoft.Management/managementGroups/upwindsecurity-sandbox'. Can be combined with subscription include/exclude filters to further refine the scope."
  type        = list(string)
  default     = []

  validation {
    condition     = var.azure_tenant_id != "" || length(var.azure_management_group_ids) > 0
    error_message = "Either azure_tenant_id or at least one azure_management_group_ids must be provided to determine the scope of role assignments."
  }
}

variable "azure_application_client_id" {
  description = "Optional client ID of an existing Azure AD application. If provided, the module will use this existing application instead of creating a new one. Mutually exclusive with azure_application_name_prefix. MSGraph permissions need to be configured manually for the existing application. Note: for a multi-tenant application registered in a different tenant, a service principal for the application must already exist in the tenant being onboarded (e.g. created via `az ad sp create --id <client_id>` or via admin consent at <https://login.microsoftonline.com/{tenant_id}/adminconsent?client_id={app_id}>) before running this module. In the multi-tenant case you must also set azure_application_service_principal_object_id — otherwise the data-source lookup of the application object fails at plan time, because the app registration lives in the home tenant and is not visible to the runner."
  type        = string
  default     = null

  validation {
    condition     = var.azure_application_client_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_application_client_id))
    error_message = "The azure_application_client_id must be a valid GUID format."
  }
}

variable "azure_application_client_secret" {
  description = "Client secret for the existing Azure AD application. Required when azure_application_client_id is provided and organizational credentials will be created. Should be managed externally (e.g., Azure Portal, CLI, or separate automation)."
  type        = string
  default     = null
  sensitive   = true
  validation {
    condition     = var.azure_application_client_id == null || (var.azure_application_client_secret != null && var.azure_application_client_secret != "")
    error_message = "The azure_application_client_secret must be provided and non-empty when azure_application_client_id is specified."
  }
  validation {
    condition     = var.azure_application_client_secret == null || !can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_application_client_secret))
    error_message = "The azure_application_client_secret appears to be a GUID, which is the secret ID rather than the secret value. Use the actual secret value from the Azure Portal (Certificates & secrets > Value column), not the Secret ID."
  }
}

variable "azure_application_service_principal_object_id" {
  description = "The service principal object ID of the existing Azure AD application. Optional, if provided the module will skip looking up the service principal object ID. Useful if graph permissions cannot be configured for the TF runner App Registration. Required when onboarding via a multi-tenant application registered in a different tenant: the app registration is not visible in the tenant being onboarded, so the data-source lookup of the application would fail at plan time — supplying the SP object ID directly bypasses that lookup. Should be managed externally (e.g., Azure Portal, CLI, or separate automation)."
  type        = string
  default     = null

  validation {
    condition     = var.azure_application_service_principal_object_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_application_service_principal_object_id))
    error_message = "The azure_application_service_principal_object_id must be a valid GUID format."
  }
}

variable "azure_application_name_prefix" {
  description = "The prefix used for the name of the Azure AD application. The prefix used for the name of the Azure AD application. Only used when creating a new application (when azure_application_client_id is not provided)."
  type        = string
  default     = "upwindsecurity"
}

variable "azure_application_owners" {
  description = "List of user IDs that will be set as owners of the Azure application. Each ID should be in the form of a GUID. If this list is left empty, the owner defaults to the authenticated principal. Only used when creating a new application (when azure_application_client_id is not provided)."
  type        = list(string)
  default     = []
}

variable "azure_application_msgraph_roles" {
  description = "List of Microsoft Graph API roles that should be granted to the Azure AD application. These permissions are required for platform functionality and will be applied to both new and existing applications."
  type        = list(string)
  default = [
    "User.Read.All",
    "Group.Read.All",
    "RoleManagement.Read.All",
    "Directory.Read.All",
    "Policy.Read.All",
    "UserAuthenticationMethod.Read.All",
  ]
}

variable "azure_roles" {
  description = "The names of the Azure roles that should be assigned to the service principal for CSPM inventory purposes."
  type        = list(string)
  default = [
    # Core read access
    "Reader",

    # Security and compliance readers
    "Security Reader",

    # Data and storage readers
    "Key Vault Reader",
    "Cosmos DB Account Reader Role",
    "Backup Reader",

    # Service-specific readers
    "Log Analytics Reader",
    "Cognitive Services Data Reader",
  ]
}

variable "azure_custom_role_name_prefix" {
  description = "The prefix used for the name of the Azure role definition."
  type        = string
  default     = "upwindsecurity"
}

variable "azure_custom_role_permissions" {
  description = "List of custom permissions that should be granted to the service principal through a custom role."
  type        = list(string)
  default = [
    "Microsoft.Web/sites/host/listkeys/action",
    "Microsoft.Web/sites/config/list/Action",
  ]
}

variable "azure_role_definition_wait_time" {
  description = "The duration of time to wait after Azure role definitions are created to ensure full propagation and prevent timing issues in dependent resources."
  type        = string
  default     = "10s"
}

# This is needed for the organizational credentials.
variable "azure_orchestrator_subscription_id" {
  description = "The subscription ID where the Upwind components will be deployed. The module will assume deployment permissions in this subscription via a custom role definition."
  type        = string
}

# All of the resources in the org-wide resource group will be deployed to this region.
# This will not have any effect on cloud scanners deployed to different regions.
# We can still deploy resources to westeurope even though we have the org-wide resource group in eastus.
variable "azure_cloudscanner_location" {
  description = "The region where the org-wide resource group will be deployed."
  type        = string
  default     = "westus"
}

variable "disable_function_scanning" {
  description = "Legacy opt-out (poorly named): if true, disables the Storage Blob Data Reader / Storage File Data Privileged Reader grants that back DSPM. Retained for backwards compatibility; prefer upwind_feature_dspm_enabled to control DSPM. DSPM is enabled only when upwind_feature_dspm_enabled is true AND this is false."
  type        = bool
  default     = false
}

variable "upwind_feature_dspm_enabled" {
  description = "Opt-in control for Upwind DSPM (Data Security Posture Management). When true (default), onboarding grants data-plane blob read (Storage Blob Data Reader / Storage File Data Privileged Reader) and, in SaaS mode, mints the DSPM marker role the CloudScanner feature gate detects. Setting this to false ALSO disables Azure Function scanning: Function apps store their code in an Azure storage account, and reading that code relies on the same Storage Blob Data Reader grant - so turning DSPM off removes function-code visibility too. Coexists with the legacy disable_function_scanning: DSPM (and function scanning) is provisioned only when this is true AND disable_function_scanning is false."
  type        = bool
  default     = true
}

variable "cloudapi_include_subscriptions" {
  description = "Optional list of subscription IDs to include for cloudapi service principal role assignments. If provided, cloudapi roles will only be assigned to these subscriptions. Mutually exclusive with cloudapi_exclude_subscriptions. Can be combined with azure_management_group_ids or azure_tenant_id. This will enable us to discover these subscriptions and the resources in them. CloudAPI scope should be a superset of cloudscanner scope."
  type        = list(string)
  default     = []
}

variable "cloudapi_exclude_subscriptions" {
  description = "Optional list of subscription IDs to exclude from cloudapi service principal role assignments. If provided, cloudapi roles will be assigned at the subscription level to all tenant subscriptions except these (instead of at management group level). Mutually exclusive with cloudapi_include_subscriptions. Note: When used with azure_management_group_ids, role assignments switch from management-group-level to subscription-level for all tenant subscriptions (excluding specified ones). This will enable us to exclude subscriptions from the discovery process. CloudAPI scope should be a superset of cloudscanner scope."
  type        = list(string)
  default     = []
}

variable "cloudscanner_include_subscriptions" {
  description = "Optional list of subscription IDs to include for cloudscanner managed identity role assignments. If provided, cloudscanner roles will only be assigned to these subscriptions. Mutually exclusive with cloudscanner_exclude_subscriptions. Can be combined with azure_management_group_ids or azure_tenant_id. This will enable us to scan resources in these subscriptions. Cloudscanner scope should be a subset of cloudapi scope."
  type        = list(string)
  default     = []
}

variable "cloudscanner_exclude_subscriptions" {
  description = "Optional list of subscription IDs to exclude from cloudscanner managed identity role assignments. If provided, cloudscanner roles will be assigned at the subscription level to all tenant subscriptions except these (instead of at management group level). Mutually exclusive with cloudscanner_include_subscriptions. Note: When used with azure_management_group_ids, role assignments switch from management-group-level to subscription-level for all tenant subscriptions (excluding specified ones). This will enable us to exclude subscriptions from the scanning process. Cloudscanner scope should be a subset of cloudapi scope."
  type        = list(string)
  default     = []
}

variable "function_storage_accounts" {
  description = "Optional list of storage account resource IDs used by Function Apps. If provided, Storage Blob Data Reader role will only be assigned to these specific storage accounts instead of all resources in scope. Use the list-function-storage-accounts.sh script to discover these. Example: [\"/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}\"]"
  type        = list(string)
  default     = []
}

# endregion azure

# region general

variable "resource_suffix" {
  description = "The suffix to append to all resources created by this module."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{0,10}$", var.resource_suffix))
    error_message = "The resource suffix must be alphanumeric and cannot exceed 10 characters."
  }
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

variable "key_vault_deny_traffic" {
  type        = bool
  description = "Whether to deny traffic to the Key Vault using network ACLs. When true, only trusted Azure services and allowed IPs can access the vault."
  default     = false
}

variable "key_vault_ip_rules" {
  type        = list(string)
  description = "One or more IP Addresses, or CIDR Blocks which should be able to access the Key Vault. This is only relevant if key_vault_deny_traffic is set to true."
  default     = []
}

variable "key_vault_private_network" {
  type        = bool
  description = "Whether to provision the Key Vault with public network access fully disabled (private networking). When true, Terraform cannot reach the vault to write secrets, so the module will NOT create the 'upwind-client-id' and 'upwind-client-secret' secrets - you must add them manually (see the key_vault_name output). CloudScanner infrastructure is still provisioned without needing scanner_client_id/scanner_client_secret. Cannot be combined with key_vault_deny_traffic."
  default     = false

  validation {
    condition     = !(var.key_vault_private_network && var.key_vault_deny_traffic)
    error_message = "key_vault_private_network and key_vault_deny_traffic are mutually exclusive. Use key_vault_private_network for a fully private vault, or key_vault_deny_traffic with key_vault_ip_rules for IP-restricted public access."
  }
}

variable "key_vault_logging_enabled" {
  type        = bool
  description = "Whether to enable diagnostic logging for the Key Vault. When true, creates a Log Analytics Workspace and configures diagnostic settings to capture AuditEvent logs and AllMetrics."
  default     = false
}

variable "key_vault_logging_retention_in_days" {
  type        = number
  description = "The number of days to retain logs in the Log Analytics Workspace. Only relevant if key_vault_logging_enabled is true."
  default     = 30
}

# endregion general

# tflint-ignore: terraform_unused_declarations
variable "skip_app_service_provider_registration" {
  type        = bool
  description = "DEPRECATED: We have removed the need for this variable. Set to true to skip the Microsoft.App provider registration, recommended if running on Windows. If resource_providers_to_register is set to [\"Microsoft.App\"] on the azurerm provider, this can safely be set to true."
  default     = false
}

variable "create_organizational_credentials" {
  description = "Set to false to skip sending organizational credentials to Upwind. The default value for this variable should be set to true for onboarding deployments using 'terraform init && terraform apply' and set to false when offboarding using 'terraform destroy'. It is essential that it is reset appropriately for subsequent deploy / destroy attempts."
  type        = bool
  default     = true
}

# region saas

variable "saas_enabled" {
  description = "Enable SaaS (provider-hosted, secretless) onboarding. When true, the customer tenant only consents to Upwind's multi-tenant Snapshot and Fetcher app registrations and assigns them scoped roles at management-group (tenant-root) scope. No app registration, Key Vault, managed identities, custom roles, scanner credentials, or Upwind API calls are created. Self-hosted resources are skipped. Defaults to false (self-hosted, unchanged)."
  type        = bool
  default     = false
}

variable "use_workload_identity_federation" {
  description = "Self-hosted (outpost) mode: authenticate via workload identity federation instead of a client secret (UP-3278). When true (the default), the module uses WIF ONLY IF a WIF identity is available - i.e. fetcher_app_client_id or fetcher_app_service_principal_object_id is set, which happens when the org has azure-auth-service enabled and the Upwind console has surfaced the Fetcher app. In WIF mode no app registration or client secret is created in this tenant and no credentials are submitted to Upwind; instead the service principal of the org's Upwind-minted WIF app registration (the same Fetcher app the SaaS mode consents) is materialized here and granted the self-hosted role set. AUTO-FALLBACK: if no fetcher_* input is provided (org WITHOUT azure auth service, or an existing client-secret deployment), the module keeps the legacy client-secret flow instead of failing - so those customers can still onboard. Set false to pin the legacy client-secret flow explicitly regardless of fetcher_* inputs. Ignored when saas_enabled is true."
  type        = bool
  default     = true
}

variable "snapshot_app_client_id" {
  description = "SaaS mode: client ID of Upwind's multi-tenant Snapshot app registration. Its service principal is materialized in the customer tenant and granted read-only roles at the tenant-root management group (Reader + a CloudScannerTargetRole custom role + Storage Blob/File data-plane readers), plus snapshot write/delete (Disk Snapshot Contributor + Data Operator for Managed Disks) confined to the central snapshots resource group in the orchestrator subscription (see customer_snapshot_resource_group). Required when saas_enabled is true, unless snapshot_app_service_principal_object_id is provided."
  type        = string
  default     = ""

  validation {
    condition     = var.snapshot_app_client_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.snapshot_app_client_id))
    error_message = "The snapshot_app_client_id must be a valid GUID format."
  }
}

variable "fetcher_app_client_id" {
  description = "Client ID of the org's Upwind-minted multi-tenant Fetcher (WIF) app registration, shown in the Upwind console. SaaS mode: its service principal is materialized in the customer tenant and granted, at the tenant-root management group, the outpost app-registration role set: the built-in read roles (var.azure_roles) + a custom role (var.azure_custom_role_permissions). WIF mode: the same service principal is materialized and granted the full self-hosted role set instead. Required when saas_enabled or use_workload_identity_federation is true, unless fetcher_app_service_principal_object_id is provided."
  type        = string
  default     = ""

  validation {
    condition     = var.fetcher_app_client_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.fetcher_app_client_id))
    error_message = "The fetcher_app_client_id must be a valid GUID format."
  }
}

variable "snapshot_app_service_principal_object_id" {
  description = "SaaS mode (optional): object ID of an existing service principal for Upwind's Snapshot app registration in the customer tenant. Provide this when the SP has already been created out-of-band (e.g. via admin consent / `az ad sp create`) and the Terraform runner lacks Microsoft Graph permissions to create it. When set, the module skips creating the service principal and assigns roles to this object ID directly; snapshot_app_client_id is then not required."
  type        = string
  default     = ""

  validation {
    condition     = var.snapshot_app_service_principal_object_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.snapshot_app_service_principal_object_id))
    error_message = "The snapshot_app_service_principal_object_id must be a valid GUID format."
  }
}

variable "fetcher_app_service_principal_object_id" {
  description = "SaaS or WIF mode (optional): object ID of an existing service principal for the org's Fetcher (WIF) app registration in the customer tenant. Provide this when the SP has already been created out-of-band (e.g. via admin consent / `az ad sp create`) and the Terraform runner lacks Microsoft Graph permissions to create it. When set, the module skips creating the service principal and assigns roles to this object ID directly; fetcher_app_client_id is then not required."
  type        = string
  default     = ""

  validation {
    condition     = var.fetcher_app_service_principal_object_id == "" || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.fetcher_app_service_principal_object_id))
    error_message = "The fetcher_app_service_principal_object_id must be a valid GUID format."
  }
}

variable "customer_snapshot_resource_group" {
  description = "SaaS mode: name of the central snapshots resource group created in the orchestrator subscription (azure_orchestrator_subscription_id). The Snapshot SP's snapshot write/delete roles (Disk Snapshot Contributor + Data Operator for Managed Disks) are confined to this RG instead of being granted tenant-wide. Defaults to upwind-cs-rg-<upwind_organization_id> when empty."
  type        = string
  default     = ""
}

# endregion saas
