# Microsoft Azure Tenant Onboarding Example

This example demonstrates how to use the Microsoft Azure Tenant Onboarding Module to connect a Microsoft Azure tenant
to the Upwind platform for comprehensive monitoring and security analysis.

## Usage

To run this example you need to execute:

```bash
terraform init
terraform plan
terraform apply
```

Run `terraform destroy` when you don't need these resources.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_upwind_integration_azure_onboarding"></a> [upwind\_integration\_azure\_onboarding](#module\_upwind\_integration\_azure\_onboarding) | ../../modules/tenant | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_orchestrator_subscription_id"></a> [azure\_orchestrator\_subscription\_id](#input\_azure\_orchestrator\_subscription\_id) | The identifier of the Azure subscription to act as the orchestrator. | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | The identifier of the Azure tenant to integrate with. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
