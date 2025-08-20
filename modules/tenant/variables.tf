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

variable "apply_to_child_groups" {
  description = "When true and azure_tenant_id is provided, permissions will be applied to all child management groups. When false, permissions will only be applied to the tenant root management group."
  type        = bool
  default     = false
}

variable "azure_management_group_ids" {
  description = "List of management group names (not full resource IDs) to grant read access to. For example, use 'upwindsecurity-sandbox' instead of '/providers/Microsoft.Management/managementGroups/upwindsecurity-sandbox'. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided."
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.azure_management_group_ids) <= 1
    error_message = "Only one management group ID is supported for organizational onboarding."
  }
}

variable "azure_application_name_prefix" {
  description = "The prefix used for the name of the Azure AD application."
  type        = string
  default     = "upwindsecurity"
}

variable "azure_application_owners" {
  description = "List of user IDs that will be set as owners of the Azure application. Each ID should be in the form of a GUID. If this list is left empty, the owner defaults to the authenticated principal."
  type        = list(string)
  default     = []
}

variable "azure_application_msgraph_roles" {
  description = "List of Microsoft Graph API roles that should be granted to the Azure AD application."
  type        = list(string)
  default = [
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
    "Microsoft.Web/sites/host/listkeys/action",
    "Microsoft.Web/sites/config/list/Action",
  ]
}

variable "azure_allow_blob_access" {
  description = "If set to true, install the permissions to provide read access to read Azure Blob Data. This is required for App Scanning"
  type        = bool
  default     = true
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

variable "create_organizational_credentials" {
  description = "Set to true to create organizational credentials for the management groups pending onboarding. Needs to be set to false before destroying module."
  type        = bool
  default     = true
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

# endregion general

variable "skip_app_service_provider_registration" {
  type        = bool
  description = "Set to true to skip the Microsoft.App provider registration. NOTE: The Microsoft.App provider must be registered in the subscription before deployments from Upwind backends can succeed."
  default     = false
}
