# Terraform Modules for Microsoft Azure Onboarding

[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=for-the-badge&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Microsoft Azure](https://img.shields.io/badge/Microsoft%20Azure-%230072C6.svg?style=for-the-badge&logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![GitHub Actions](https://img.shields.io/badge/github%20actions-%232671E5.svg?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/features/actions)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg?style=for-the-badge)](https://opensource.org/licenses/Apache-2.0)

A comprehensive collection of Terraform modules for onboarding Microsoft Azure subscriptions and management groups to the
Upwind platform, enabling seamless integration for monitoring and security analysis.

## Modules

This repository contains the following Terraform modules for Microsoft Azure onboarding:

- [modules/organization/](./modules/organization/) - Management group-level onboarding module for comprehensive monitoring
  and security analysis across entire Azure management groups

## Examples

Complete usage examples are available in the [examples](./examples/) directory:

- [examples/organization/](./examples/organization/) - Advanced management group-level onboarding with multiple subscription
  scenarios and conditional deployments

## Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](./CONTRIBUTING.md) guide for details on:

- Development setup and workflows
- Testing procedures
- Code standards and best practices
- How to add new submodules

For bug reports and feature requests, please use
[GitHub Issues](https://github.com/upwindsecurity/terraform-azurerm-onboarding/issues).

## Versioning

We use [Semantic Versioning](http://semver.org/) for releases. For the versions
available, see the [tags on this repository](https://github.com/upwindsecurity/terraform-azurerm-onboarding/tags).

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Support

- [Documentation](https://docs.upwind.io)
- [Issues](https://github.com/upwindsecurity/terraform-azurerm-onboarding/issues)
- [Contributing Guide](./CONTRIBUTING.md)
