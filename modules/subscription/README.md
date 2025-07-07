# Microsoft Azure Subscription Onboarding Module

This Terraform module handles the onboarding of Microsoft Azure subscriptions to the Upwind platform, enabling users to seamlessly connect their subscriptions for comprehensive monitoring and security analysis.

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

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | ~> 2.53 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 3.111 |
| <a name="provider_http"></a> [http](#provider\_http) | ~> 3.4 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.5 |
| <a name="provider_time"></a> [time](#provider\_time) | ~> 0.8 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_api_access.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_api_access) | resource |
| [azuread_application_password.client_secret](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.builtin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [random_id.rid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.uid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.azurerm_builtin_role_assignment_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.azurerm_custom_role_assignment_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azuread_application_published_app_ids.well_known](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application_published_app_ids) | data source |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principal.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |
| [azurerm_management_group.all](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/management_group) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [azurerm_subscriptions.available](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscriptions) | data source |
| [http_http.upwind_create_cloud_credentials_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.upwind_get_access_token_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.upwind_get_cloud_credentials_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_application_msgraph_roles"></a> [azure\_application\_msgraph\_roles](#input\_azure\_application\_msgraph\_roles) | List of Microsoft Graph API roles that should be granted to the Azure AD application. | `list(string)` | <pre>[<br>  "Directory.Read.All",<br>  "Policy.Read.All",<br>  "UserAuthenticationMethod.Read.All"<br>]</pre> | no |
| <a name="input_azure_application_name_prefix"></a> [azure\_application\_name\_prefix](#input\_azure\_application\_name\_prefix) | The prefix used for the name of the Azure AD application. | `string` | `"upwindsecurity"` | no |
| <a name="input_azure_application_owners"></a> [azure\_application\_owners](#input\_azure\_application\_owners) | List of user IDs that will be set as owners of the Azure application. Each ID should be in the form of a GUID. If this list is left empty, the owner defaults to the authenticated principal. | `list(string)` | `[]` | no |
| <a name="input_azure_custom_role_name_prefix"></a> [azure\_custom\_role\_name\_prefix](#input\_azure\_custom\_role\_name\_prefix) | The prefix used for the name of the Azure role definition. | `string` | `"upwindsecurity"` | no |
| <a name="input_azure_custom_role_permissions"></a> [azure\_custom\_role\_permissions](#input\_azure\_custom\_role\_permissions) | List of custom permissions that should be granted to the service principal through a custom role. | `list(string)` | <pre>[<br>  "Microsoft.Web/sites/host/listkeys/action",<br>  "Microsoft.Web/sites/config/list/Action"<br>]</pre> | no |
| <a name="input_azure_exclude_subscription_ids"></a> [azure\_exclude\_subscription\_ids](#input\_azure\_exclude\_subscription\_ids) | List of subscription IDs to EXCLUDE when granting read access to. This variable is mutually exclusive with `azure_include_subscription_ids`. | `list(string)` | `[]` | no |
| <a name="input_azure_include_all_subscriptions"></a> [azure\_include\_all\_subscriptions](#input\_azure\_include\_all\_subscriptions) | When set to true, grant read access to ALL subscriptions within the tenant. Overrides `azure_include_subscription_ids`. | `bool` | `false` | no |
| <a name="input_azure_include_subscription_ids"></a> [azure\_include\_subscription\_ids](#input\_azure\_include\_subscription\_ids) | List of subscription IDs to INCLUDE when granting read access to. If `azure_include_all_subscriptions` is false and this list is left empty, only the current subscription is included. This variable is mutually exclusive with `azure_exclude_subscription_ids`. | `list(string)` | `[]` | no |
| <a name="input_azure_management_group_ids"></a> [azure\_management\_group\_ids](#input\_azure\_management\_group\_ids) | List of management group IDs to grant read access to. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided. | `list(string)` | `[]` | no |
| <a name="input_azure_role_assignment_wait_time"></a> [azure\_role\_assignment\_wait\_time](#input\_azure\_role\_assignment\_wait\_time) | The duration of time to wait after Azure role assignments to ensure full propagation and prevent timing issues in dependent resources. | `string` | `"30s"` | no |
| <a name="input_azure_roles"></a> [azure\_roles](#input\_azure\_roles) | The names of the Azure roles that should be assigned to the service principal. | `list(string)` | <pre>[<br>  "Reader"<br>]</pre> | no |
| <a name="input_upwind_auth_endpoint"></a> [upwind\_auth\_endpoint](#input\_upwind\_auth\_endpoint) | The Authentication API endpoint. | `string` | `"https://auth.upwind.io"` | no |
| <a name="input_upwind_client_id"></a> [upwind\_client\_id](#input\_upwind\_client\_id) | The client ID used for authentication with the Upwind Authorization Service. | `string` | n/a | yes |
| <a name="input_upwind_client_secret"></a> [upwind\_client\_secret](#input\_upwind\_client\_secret) | The client secret for authentication with the Upwind Authorization Service. | `string` | n/a | yes |
| <a name="input_upwind_integration_endpoint"></a> [upwind\_integration\_endpoint](#input\_upwind\_integration\_endpoint) | The Integration API endpoint. | `string` | `"https://integration.upwind.io"` | no |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The identifier of the Upwind organization to integrate with. | `string` | n/a | yes |
| <a name="input_upwind_region"></a> [upwind\_region](#input\_upwind\_region) | Which Upwind region to communicate with. 'us' or 'eu' | `string` | `"us"` | no |

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
