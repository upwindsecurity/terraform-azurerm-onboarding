# region upwind

variable "upwind_organization_id" {
  description = "The identifier of the Upwind organization to integrate with."
  type        = string
}

variable "upwind_region" {
  type        = string
  description = "Which Upwind region to communicate with. 'us', 'eu' or 'me'"
  default     = "us"

  validation {
    condition     = var.upwind_region == "us" || var.upwind_region == "eu" || var.upwind_region == "me"
    error_message = "upwind_region must be either 'us', 'eu' or 'me'."
  }
}

variable "upwind_client_id" {
  description = "The client ID used for authentication with the Upwind Authorization Service."
  type        = string
}

variable "upwind_client_secret" {
  description = "The client secret for authentication with the Upwind Authorization Service."
  type        = string
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

# endregion upwind

# region azure

variable "azure_include_all_subscriptions" {
  description = "When set to true, grant read access to ALL subscriptions within the tenant. Overrides `azure_include_subscription_ids`."
  type        = bool
  default     = false
}

variable "azure_include_subscription_ids" {
  description = "List of subscription IDs to INCLUDE when granting read access to. If `azure_include_all_subscriptions` is false and this list is left empty, only the current subscription is included. This variable is mutually exclusive with `azure_exclude_subscription_ids`."
  type        = list(string)
  default     = []
}

variable "azure_exclude_subscription_ids" {
  description = "List of subscription IDs to EXCLUDE when granting read access to. This variable is mutually exclusive with `azure_include_subscription_ids`."
  type        = list(string)
  default     = []
}

variable "azure_management_group_ids" {
  description = "List of management group IDs to grant read access to. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided."
  type        = list(string)
  default     = []
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
    "User.Read.All",
    "Group.Read.All",
    "RoleManagement.Read.All",
    "Directory.Read.All",
    "Application.Read.All",
    "Policy.Read.All",
    "UserAuthenticationMethod.Read.All",
  ]
}

variable "azure_roles" {
  description = "The names of the Azure roles that should be assigned to the service principal."
  type        = list(string)
  default     = ["Reader"]
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

variable "azure_role_assignment_wait_time" {
  description = "The duration of time to wait after Azure role assignments to ensure full propagation and prevent timing issues in dependent resources."
  type        = string
  default     = "30s"
}

# endregion azure
