# Microsoft Azure Tenant Onboarding Module

This Terraform module handles the onboarding of Microsoft Azure tenants to the Upwind platform, enabling users to
seamlessly connect their entire tenant for comprehensive monitoring and security analysis.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.2 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 2.53 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.111 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.8 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | 3.4.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 4.35.0 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.5.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.4 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |
| <a name="provider_time"></a> [time](#provider\_time) | 0.13.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_api_access.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_api_access) | resource |
| [azuread_application_password.client_secret](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.this](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_key_vault.orgwide_key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.scanner_client_id](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.scanner_client_secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_private_dns_zone.orgwide_keyvault_dns_zone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_resource_group.orgwide_resource_group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.builtin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.cloudscanner_scaler](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.cloudscanner_worker](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.deployer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.disk_encryption_key_vault_access](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kv_admin](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kv_secrets_scaler](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kv_secrets_worker](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.storage_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.target_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.cloudscanner_scaler](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.cloudscanner_worker](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.custom](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.deployer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.target_role](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.key_vault_access](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.scaler_user_assigned_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.worker_user_assigned_identity](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [null_resource.register_app_service_provider](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_id.rid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [random_id.uid](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.builtin_role_assignment_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.cloudscanner_scaler_role_definition_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.cloudscanner_worker_role_definition_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.deployer_role_definition_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.target_role_definition_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azuread_application.existing](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application) | data source |
| [azuread_application_published_app_ids.well_known](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/application_published_app_ids) | data source |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azuread_service_principal.existing](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |
| [azuread_service_principal.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |
| [azurerm_subscription.orchestrator](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [azurerm_subscriptions.all](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscriptions) | data source |
| [http_http.upwind_create_organizational_credentials_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.upwind_get_access_token_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |
| [http_http.upwind_get_organizational_credentials_request](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_application_client_id"></a> [azure\_application\_client\_id](#input\_azure\_application\_client\_id) | Optional client ID of an existing Azure AD application. If provided, the module will use this existing application instead of creating a new one. Mutually exclusive with azure\_application\_name\_prefix. | `string` | `null` | no |
| <a name="input_azure_application_client_secret"></a> [azure\_application\_client\_secret](#input\_azure\_application\_client\_secret) | Client secret for the existing Azure AD application. Required when azure\_application\_client\_id is provided and organizational credentials will be created. Should be managed externally (e.g., Azure Portal, CLI, or separate automation). | `string` | `null` | no |
| <a name="input_azure_application_msgraph_roles"></a> [azure\_application\_msgraph\_roles](#input\_azure\_application\_msgraph\_roles) | List of Microsoft Graph API roles that should be granted to the Azure AD application. These permissions are required for platform functionality and will be applied to both new and existing applications. | `list(string)` | <pre>[<br/>  "User.Read.All",<br/>  "Group.Read.All",<br/>  "RoleManagement.Read.All",<br/>  "Directory.Read.All",<br/>  "Policy.Read.All",<br/>  "UserAuthenticationMethod.Read.All"<br/>]</pre> | no |
| <a name="input_azure_application_name_prefix"></a> [azure\_application\_name\_prefix](#input\_azure\_application\_name\_prefix) | The prefix used for the name of the Azure AD application. The prefix used for the name of the Azure AD application. Only used when creating a new application (when azure\_application\_client\_id is not provided). | `string` | `"upwindsecurity"` | no |
| <a name="input_azure_application_owners"></a> [azure\_application\_owners](#input\_azure\_application\_owners) | List of user IDs that will be set as owners of the Azure application. Each ID should be in the form of a GUID. If this list is left empty, the owner defaults to the authenticated principal. Only used when creating a new application (when azure\_application\_client\_id is not provided). | `list(string)` | `[]` | no |
| <a name="input_azure_cloudscanner_location"></a> [azure\_cloudscanner\_location](#input\_azure\_cloudscanner\_location) | The region where the org-wide resource group will be deployed. | `string` | `"westus"` | no |
| <a name="input_azure_custom_role_name_prefix"></a> [azure\_custom\_role\_name\_prefix](#input\_azure\_custom\_role\_name\_prefix) | The prefix used for the name of the Azure role definition. | `string` | `"upwindsecurity"` | no |
| <a name="input_azure_custom_role_permissions"></a> [azure\_custom\_role\_permissions](#input\_azure\_custom\_role\_permissions) | List of custom permissions that should be granted to the service principal through a custom role. | `list(string)` | <pre>[<br/>  "Microsoft.Web/sites/host/listkeys/action",<br/>  "Microsoft.Web/sites/config/list/Action"<br/>]</pre> | no |
| <a name="input_azure_management_group_ids"></a> [azure\_management\_group\_ids](#input\_azure\_management\_group\_ids) | List of management group names (not full resource IDs) to grant read access to. For example, use 'upwindsecurity-sandbox' instead of '/providers/Microsoft.Management/managementGroups/upwindsecurity-sandbox'. This variable is mutually exclusive with `azure_include_all_subscriptions` and `azure_include_subscription_ids`, and it takes precedence if both sets of variables are provided. | `list(string)` | `[]` | no |
| <a name="input_azure_orchestrator_subscription_id"></a> [azure\_orchestrator\_subscription\_id](#input\_azure\_orchestrator\_subscription\_id) | The subscription ID where the Upwind components will be deployed. The module will assume deployment permissions in this subscription via a custom role definition. | `string` | n/a | yes |
| <a name="input_azure_role_definition_wait_time"></a> [azure\_role\_definition\_wait\_time](#input\_azure\_role\_definition\_wait\_time) | The duration of time to wait after Azure role definitions are created to ensure full propagation and prevent timing issues in dependent resources. | `string` | `"10s"` | no |
| <a name="input_azure_roles"></a> [azure\_roles](#input\_azure\_roles) | The names of the Azure roles that should be assigned to the service principal for CSPM inventory purposes. | `list(string)` | <pre>[<br/>  "Reader",<br/>  "Security Reader",<br/>  "Key Vault Reader",<br/>  "Cosmos DB Account Reader Role",<br/>  "Backup Reader",<br/>  "Log Analytics Reader"<br/>]</pre> | no |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | The Azure Tenant that will be onboarded to the Upwind organization. | `string` | `""` | no |
| <a name="input_cloudapi_exclude_subscriptions"></a> [cloudapi\_exclude\_subscriptions](#input\_cloudapi\_exclude\_subscriptions) | Optional list of subscription IDs to exclude from cloudapi service principal role assignments. If provided, cloudapi roles will be assigned to all organizational subscriptions except these. Mutually exclusive with cloudapi\_include\_subscriptions. This will enable us to exclude subscriptions from the discovery process. CloudAPI scope should be a superset of cloudscanner scope. | `list(string)` | `[]` | no |
| <a name="input_cloudapi_include_subscriptions"></a> [cloudapi\_include\_subscriptions](#input\_cloudapi\_include\_subscriptions) | Optional list of subscription IDs to include for cloudapi service principal role assignments. If provided, cloudapi roles will only be assigned to these subscriptions. Mutually exclusive with cloudapi\_exclude\_subscriptions. This will enable us to discover these subscriptions and the resources in them. CloudAPI scope should be a superset of cloudscanner scope. | `list(string)` | `[]` | no |
| <a name="input_cloudscanner_exclude_subscriptions"></a> [cloudscanner\_exclude\_subscriptions](#input\_cloudscanner\_exclude\_subscriptions) | Optional list of subscription IDs to exclude from cloudscanner managed identity role assignments. If provided, cloudscanner roles will be assigned to all organizational subscriptions except these. Mutually exclusive with cloudscanner\_include\_subscriptions. This will enable us to exclude subscriptions from the scanning process. Cloudscanner scope should be a subset of cloudapi scope. | `list(string)` | `[]` | no |
| <a name="input_cloudscanner_include_subscriptions"></a> [cloudscanner\_include\_subscriptions](#input\_cloudscanner\_include\_subscriptions) | Optional list of subscription IDs to include for cloudscanner managed identity role assignments. If provided, cloudscanner roles will only be assigned to these subscriptions. Mutually exclusive with cloudscanner\_exclude\_subscriptions. This will enable us to scan resources in these subscriptions. Cloudscanner scope should be a subset of cloudapi scope. | `list(string)` | `[]` | no |
| <a name="input_create_organizational_credentials"></a> [create\_organizational\_credentials](#input\_create\_organizational\_credentials) | Set to true to create organizational credentials for the management groups pending onboarding. Needs to be set to false before destroying module. | `bool` | `true` | no |
| <a name="input_disable_function_scanning"></a> [disable\_function\_scanning](#input\_disable\_function\_scanning) | If set to true will disable Storage Blob Data Reader role assignment for upwind-cs-vmss-identity | `bool` | `false` | no |
| <a name="input_key_vault_deny_traffic"></a> [key\_vault\_deny\_traffic](#input\_key\_vault\_deny\_traffic) | Whether to deny traffic to the Key Vault using network ACLs. When true, only trusted Azure services and allowed IPs can access the vault. | `bool` | `true` | no |
| <a name="input_key_vault_ip_rules"></a> [key\_vault\_ip\_rules](#input\_key\_vault\_ip\_rules) | One or more IP Addresses, or CIDR Blocks which should be able to access the Key Vault. This is only relevant if key\_vault\_deny\_traffic is set to true. | `list(string)` | `[]` | no |
| <a name="input_resource_suffix"></a> [resource\_suffix](#input\_resource\_suffix) | The suffix to append to all resources created by this module. | `string` | `""` | no |
| <a name="input_scanner_client_id"></a> [scanner\_client\_id](#input\_scanner\_client\_id) | The client ID used for authentication with the Upwind CloudScanner Service. | `string` | `""` | no |
| <a name="input_scanner_client_secret"></a> [scanner\_client\_secret](#input\_scanner\_client\_secret) | The client secret for authentication with the Upwind CloudScanner Service. | `string` | `""` | no |
| <a name="input_skip_app_service_provider_registration"></a> [skip\_app\_service\_provider\_registration](#input\_skip\_app\_service\_provider\_registration) | Set to true to skip the Microsoft.App provider registration. NOTE: The Microsoft.App provider must be registered in the subscription before deployments from Upwind backends can succeed. | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources. | `map(string)` | `{}` | no |
| <a name="input_upwind_auth_endpoint"></a> [upwind\_auth\_endpoint](#input\_upwind\_auth\_endpoint) | The Authentication API endpoint. | `string` | `"https://auth.upwind.io"` | no |
| <a name="input_upwind_client_id"></a> [upwind\_client\_id](#input\_upwind\_client\_id) | The client ID used for authentication with the Upwind Authorization Service. | `string` | n/a | yes |
| <a name="input_upwind_client_secret"></a> [upwind\_client\_secret](#input\_upwind\_client\_secret) | The client secret for authentication with the Upwind Authorization Service. | `string` | n/a | yes |
| <a name="input_upwind_integration_endpoint"></a> [upwind\_integration\_endpoint](#input\_upwind\_integration\_endpoint) | The Integration API endpoint. | `string` | `"https://integration.upwind.io"` | no |
| <a name="input_upwind_organization_id"></a> [upwind\_organization\_id](#input\_upwind\_organization\_id) | The identifier of the Upwind organization to integrate with. | `string` | n/a | yes |
| <a name="input_upwind_region"></a> [upwind\_region](#input\_upwind\_region) | The region where the Upwind components will be deployed. Must be 'us', 'eu' or 'me' | `string` | `"us"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_application_client_id"></a> [azure\_application\_client\_id](#output\_azure\_application\_client\_id) | The unique identifier for the Azure AD application (client). |
| <a name="output_azure_application_client_secret"></a> [azure\_application\_client\_secret](#output\_azure\_application\_client\_secret) | The client secret for the Azure AD application. |
| <a name="output_azure_application_name"></a> [azure\_application\_name](#output\_azure\_application\_name) | The display name for the Azure AD application. |
| <a name="output_azure_service_principal_id"></a> [azure\_service\_principal\_id](#output\_azure\_service\_principal\_id) | The unique identifier for the Azure AD service principal. |
| <a name="output_azure_tenant_id"></a> [azure\_tenant\_id](#output\_azure\_tenant\_id) | The unique identifier for the current Azure tenant. |
| <a name="output_organizational_credentials"></a> [organizational\_credentials](#output\_organizational\_credentials) | The Upwind organizational credentials that were created to onboard the Azure tenant. |
| <a name="output_pending_tenants"></a> [pending\_tenants](#output\_pending\_tenants) | The list of management groups that are pending onboarding. |
| <a name="output_upwind_next_step"></a> [upwind\_next\_step](#output\_upwind\_next\_step) | The instructions for the next step in the process. |
<!-- END_TF_DOCS -->
