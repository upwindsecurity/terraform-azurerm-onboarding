# region azure
variable "azure_tenant_id" {
  type        = string
  description = "The identifier of the Azure tenant to integrate with."
}

variable "azure_orchestrator_subscription_id" {
  type        = string
  description = "The identifier of the Azure subscription to act as the orchestrator."
}

# endregion azure
