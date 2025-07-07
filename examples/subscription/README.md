# azure-cloud-credentials

Terraform module for connecting Microsoft Azure subscription/s to Upwind Security.

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

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.53 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.111 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.8 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_upwind_cloud_credentials"></a> [upwind\_cloud\_credentials](#module\_upwind\_cloud\_credentials) | ../../modules/subscription | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_exclude_subscription_ids"></a> [azure\_exclude\_subscription\_ids](#input\_azure\_exclude\_subscription\_ids) | List of subscription IDs to EXCLUDE when granting read access to. This variable is mutually exclusive with `azure_include_subscription_ids`. | `list(string)` | `[]` | no |
| <a name="input_azure_include_all_subscriptions"></a> [azure\_include\_all\_subscriptions](#input\_azure\_include\_all\_subscriptions) | When set to true, grant read access to ALL subscriptions within the tenant. Overrides `azure_include_subscription_ids`. | `bool` | `false` | no |
| <a name="input_azure_include_subscription_ids"></a> [azure\_include\_subscription\_ids](#input\_azure\_include\_subscription\_ids) | List of subscription IDs to INCLUDE when granting read access to. If `azure_include_all_subscriptions` is false and this list is left empty, only the current subscription is included. This variable is mutually exclusive with `azure_exclude_subscription_ids`. | `list(string)` | `[]` | no |
| <a name="input_azure_management_group_ids"></a> [azure\_management\_group\_ids](#input\_azure\_management\_group\_ids) | List of management group IDs to grant read access to. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided. | `list(string)` | `[]` | no |
| <a name="input_create"></a> [create](#input\_create) | Controls whether resources should be created. Affects all resources. | `bool` | `true` | no |
| <a name="input_upwind_client_id"></a> [upwind\_client\_id](#input\_upwind\_client\_id) | The client ID used for authentication with the Upwind Authorization Service. | `string` | `null` | no |
| <a name="input_upwind_client_secret"></a> [upwind\_client\_secret](#input\_upwind\_client\_secret) | The client secret for authentication with the Upwind Authorization Service. | `string` | `null` | no |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The identifier of the Upwind organization to integrate with. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_application_client_id"></a> [azure\_application\_client\_id](#output\_azure\_application\_client\_id) | The unique identifier for the Azure AD application (client). |
| <a name="output_azure_application_client_secret"></a> [azure\_application\_client\_secret](#output\_azure\_application\_client\_secret) | The client secret for the Azure AD application. |
| <a name="output_azure_application_name"></a> [azure\_application\_name](#output\_azure\_application\_name) | The display name for the Azure AD application. |
| <a name="output_azure_service_principal_id"></a> [azure\_service\_principal\_id](#output\_azure\_service\_principal\_id) | The unique identifier for the Azure AD service principal. |
| <a name="output_azure_subscription_ids"></a> [azure\_subscription\_ids](#output\_azure\_subscription\_ids) | The list of Azure subscription IDs that are included based on the current configuration. |
| <a name="output_azure_tenant_id"></a> [azure\_tenant\_id](#output\_azure\_tenant\_id) | The unique identifier for the current Azure tenant. |
| <a name="output_upwind_next_step"></a> [upwind\_next\_step](#output\_upwind\_next\_step) | The instructions for the next step in the process. |
<!-- END_TF_DOCS -->
