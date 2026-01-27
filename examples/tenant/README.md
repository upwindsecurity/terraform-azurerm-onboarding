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
| <a name="module_upwind_integration_azure_onboarding"></a> [upwind\_integration\_azure\_onboarding](#module\_upwind\_integration\_azure\_onboarding) | upwindsecurity/onboarding/azurerm//modules/tenant | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create"></a> [create](#input\_create) | Controls whether resources should be created. Affects all resources. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_application_client_id"></a> [azure\_application\_client\_id](#output\_azure\_application\_client\_id) | The unique identifier for the Azure AD application (client). |
| <a name="output_azure_application_client_secret"></a> [azure\_application\_client\_secret](#output\_azure\_application\_client\_secret) | The client secret for the Azure AD application. |
| <a name="output_azure_application_name"></a> [azure\_application\_name](#output\_azure\_application\_name) | The display name for the Azure AD application. |
| <a name="output_azure_service_principal_id"></a> [azure\_service\_principal\_id](#output\_azure\_service\_principal\_id) | The unique identifier for the Azure AD service principal. |
| <a name="output_azure_tenant_id"></a> [azure\_tenant\_id](#output\_azure\_tenant\_id) | The unique identifier for the current Azure tenant. |
| <a name="output_organizational_credentials"></a> [organizational\_credentials](#output\_organizational\_credentials) | The Upwind organizational credentials that were created to onboard the Azure tenant. |
| <a name="output_upwind_next_step"></a> [upwind\_next\_step](#output\_upwind\_next\_step) | The instructions for the next step in the process. |
<!-- END_TF_DOCS -->
