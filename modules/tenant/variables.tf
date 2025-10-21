# region upwind

variable "upwind_organization_id" {
  description = "The identifier of the Upwind organization to integrate with."
  type        = string
}

variable "upwind_client_id" {
  description = "The client ID used for authentication with the Upwind Authorization Service."
  type        = string
}

variable "upwind_client_secret" {
  description = "The client secret for authentication with the Upwind Authorization Service."
  type        = string
  sensitive   = true
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
  description = "The region where the Upwind components will be deployed. Must be 'us', 'eu' or 'me'"
  type        = string
  default     = "us"

  validation {
    condition     = var.upwind_region == "us" || var.upwind_region == "eu" || var.upwind_region == "me"
    error_message = "upwind_region must be either 'us', 'eu' or 'me'."
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
  description = "List of management group names (not full resource IDs) to grant read access to. For example, use 'upwindsecurity-sandbox' instead of '/providers/Microsoft.Management/managementGroups/upwindsecurity-sandbox'. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided."
  type        = list(string)
  default     = []
}

variable "azure_application_client_id" {
  description = "Optional client ID of an existing Azure AD application. If provided, the module will use this existing application instead of creating a new one. Mutually exclusive with azure_application_name_prefix. MSGraph permissions need to be configured manually for the existing application."
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
  description = "If set to true will disable Storage Blob Data Reader role assignment for upwind-cs-vmss-identity"
  type        = bool
  default     = false
}

variable "cloudapi_include_subscriptions" {
  description = "Optional list of subscription IDs to include for cloudapi service principal role assignments. If provided, cloudapi roles will only be assigned to these subscriptions. Mutually exclusive with cloudapi_exclude_subscriptions. This will enable us to discover these subscriptions and the resources in them. CloudAPI scope should be a superset of cloudscanner scope."
  type        = list(string)
  default     = []
}

variable "cloudapi_exclude_subscriptions" {
  description = "Optional list of subscription IDs to exclude from cloudapi service principal role assignments. If provided, cloudapi roles will be assigned to all organizational subscriptions except these. Mutually exclusive with cloudapi_include_subscriptions. This will enable us to exclude subscriptions from the discovery process. CloudAPI scope should be a superset of cloudscanner scope."
  type        = list(string)
  default     = []
}

variable "cloudscanner_include_subscriptions" {
  description = "Optional list of subscription IDs to include for cloudscanner managed identity role assignments. If provided, cloudscanner roles will only be assigned to these subscriptions. Mutually exclusive with cloudscanner_exclude_subscriptions. This will enable us to scan resources in these subscriptions. Cloudscanner scope should be a subset of cloudapi scope."
  type        = list(string)
  default     = []
}

variable "cloudscanner_exclude_subscriptions" {
  description = "Optional list of subscription IDs to exclude from cloudscanner managed identity role assignments. If provided, cloudscanner roles will be assigned to all organizational subscriptions except these. Mutually exclusive with cloudscanner_include_subscriptions. This will enable us to exclude subscriptions from the scanning process. Cloudscanner scope should be a subset of cloudapi scope."
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

# endregion general

variable "skip_app_service_provider_registration" {
  type        = bool
  description = "Set to true to skip the Microsoft.App provider registration. NOTE: The Microsoft.App provider must be registered in the subscription before deployments from Upwind backends can succeed."
  default     = false
}

variable "create_organizational_credentials" {
  description = "Set to true to create organizational credentials for the management groups pending onboarding. Needs to be set to false before destroying module."
  type        = bool
  default     = true
}
