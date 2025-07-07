# region local

variable "create" {
  description = "Controls whether resources should be created. Affects all resources."
  type        = bool
  default     = true
}

# endregion local

# region upwind

variable "upwind_organization_id" {
  description = "The identifier of the Upwind organization to integrate with."
  type        = string
}

variable "upwind_client_id" {
  description = "The client ID used for authentication with the Upwind Authorization Service."
  type        = string
  default     = null
}

variable "upwind_client_secret" {
  description = "The client secret for authentication with the Upwind Authorization Service."
  type        = string
  default     = null
}

# endregion upwind

# region azure

# tflint-ignore: terraform_unused_declarations
variable "azure_include_all_subscriptions" {
  description = "When set to true, grant read access to ALL subscriptions within the tenant. Overrides `azure_include_subscription_ids`."
  type        = bool
  default     = false
}

# tflint-ignore: terraform_unused_declarations
variable "azure_include_subscription_ids" {
  description = "List of subscription IDs to INCLUDE when granting read access to. If `azure_include_all_subscriptions` is false and this list is left empty, only the current subscription is included. This variable is mutually exclusive with `azure_exclude_subscription_ids`."
  type        = list(string)
  default     = []
}

# tflint-ignore: terraform_unused_declarations
variable "azure_exclude_subscription_ids" {
  description = "List of subscription IDs to EXCLUDE when granting read access to. This variable is mutually exclusive with `azure_include_subscription_ids`."
  type        = list(string)
  default     = []
}

# tflint-ignore: terraform_unused_declarations
variable "azure_management_group_ids" {
  description = "List of management group IDs to grant read access to. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided."
  type        = list(string)
  default     = []
}

# endregion azure
