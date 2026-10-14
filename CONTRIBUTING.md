# Contributing

Thank you for your interest in contributing to this Terraform module. This document provides comprehensive
guidelines for contributors, from development setup to submitting pull requests.

## Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code.
Please report unacceptable behavior to the project maintainers.

## How to Contribute

### Reporting Issues

- Use the GitHub issue tracker to report bugs or request features
- Before creating an issue, please search existing issues to avoid duplicates
- Provide as much detail as possible, including:
  - Terraform version
  - Provider versions
  - Steps to reproduce
  - Expected vs actual behavior

### Development Process

1. Fork the repository
2. Create a feature branch from `main` (`git checkout -b feature/amazing-feature`)
3. Make your changes following the guidelines below
4. Run tests (`make test-all`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Submit a pull request

## Development Setup

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [terraform-docs](https://terraform-docs.io/) for documentation generation
- [pre-commit](https://pre-commit.com/) for code quality checks
- [tflint](https://github.com/terraform-linters/tflint) for linting
- [trivy](https://github.com/aquasecurity/trivy) for security scanning

### Recommended Tools

- [tfenv](https://github.com/tfutils/tfenv) for Terraform version management
- [Visual Studio Code](https://code.visualstudio.com/) with Terraform extension
- [direnv](https://direnv.net/) for environment variable management

### Initial Setup

1. Clone your fork:

   ```bash
   git clone https://github.com/your-username/terraform-module-template.git
   cd terraform-module-template
   ```

2. Install pre-commit hooks:

   ```bash
   make pre-commit
   ```

3. Run initial tests:

   ```bash
   # Install dependencies and run basic tests
   make test

   # Generate documentation for all modules
   make docs

   # Validate terraform configuration
   make test-validate

   # Format code
   make fmt
   ```

### Environment Configuration (Optional)

This project supports [direnv](https://direnv.net/) for automatic environment variable management:

1. Install direnv: `brew install direnv` (macOS) or see [direnv installation](https://direnv.net/docs/installation.html)
2. Copy the example: `cp .envrc.example .envrc`
3. Edit `.envrc` with your AWS credentials and preferences
4. Allow direnv: `direnv allow`

The `.envrc` file can contain:

- AWS profile and region settings
- Terraform variables
- Development tool configurations
- Project-specific aliases

## Development Guidelines

### Adding New Submodules

To add a new submodule to this template:

1. **Create module directory**: Create a new directory under `modules/`
2. **Add Terraform files**: Add your Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`)
3. **Create module README**: Create a `README.md` with terraform-docs hooks (see existing modules for examples)
4. **Update main README**: Document the new submodule in the main README.md
5. **Add examples**: Create examples in the `examples/` directory
6. **Update CI/CD**: Add the new module to any CI/CD workflows

#### Module Structure

Each submodule should follow this structure:

```text
modules/
└── your-module/
    ├── main.tf          # Main resources
    ├── variables.tf     # Input variables
    ├── outputs.tf       # Output values
    ├── versions.tf      # Provider requirements
    └── README.md        # Module documentation (terraform-docs)
```

### Coding Standards

#### Terraform Code

- Follow [Terraform best practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- Use consistent naming conventions (snake_case)
- Include descriptions for all variables and outputs
- Use appropriate variable types and validation
- Keep resources organized and well-commented
- Use meaningful variable and resource names

#### Documentation Standards

- Use terraform-docs for auto-generated documentation
- Include usage examples in module READMEs
- Document all variables with descriptions and types
- Provide meaningful output descriptions
- Include examples that demonstrate real-world usage
- Update README.md when adding new features
- Use clear, concise language
- Follow markdown best practices

#### Commit Message Format

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

**Types:**

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `build`: Changes that affect the build system or external dependencies
- `ci`: Changes to CI configuration files and scripts
- `chore`: Other changes that don't modify src or test files

**Examples:**

```text
feat: add support for bucket lifecycle configuration
fix: resolve issue with bucket versioning
docs: update README with new examples
```

## Testing

This template includes comprehensive testing:

- **Static Analysis**: terraform validate, fmt, tflint, trivy
- **Unit Tests**: Variable validation and resource configuration
- **Integration Tests**: Complete deployment scenarios in examples/
- **Security Scanning**: Automated security vulnerability detection

### Running Tests

```bash
# Run all tests
make test-all

# Run specific test types
make test-lint
make test-security
make test-validate
make test-format

# Run tests for a specific module
make test-module MODULE=main

# Run example tests
make test-examples
```

### Test Types

#### Static Analysis

- **terraform validate**: Validates Terraform syntax and configuration
- **terraform fmt**: Checks code formatting
- **tflint**: Lints Terraform code for best practices
- **trivy**: Scans for security vulnerabilities and misconfigurations

#### Integration Tests

- **Example deployments**: Tests that examples can be deployed successfully
- **Module combinations**: Tests different module configurations
- **Provider compatibility**: Tests with different provider versions

Before submitting a pull request, ensure all tests pass:

```bash
# Run basic tests
make test

# Run all tests including security scan
make test-all

# Test examples
make test-examples
```

## Pull Request Process

### Before Submitting

1. **Update documentation** if you're adding new features
2. **Add or update tests** as appropriate
3. **Ensure all CI checks pass**
4. **Run pre-commit hooks**: `pre-commit run --all-files`

### Pull Request Template

When creating a pull request, please include:

- **Description** of changes
- **Type of change** (bug fix, new feature, etc.)
- **Testing** performed
- **Breaking changes** (if any)
- **Related issues** (if applicable)

### Review Process

1. **Request review** from maintainers
2. **Address feedback** promptly
3. **Keep pull requests focused** and atomic
4. **Be responsive** to reviewer comments

## Code Review Guidelines

### For Contributors

- Keep pull requests focused and atomic
- Write clear commit messages
- Include tests for new functionality
- Update documentation as needed
- Be responsive to feedback

### For Reviewers

- Be constructive and helpful
- Focus on code quality and maintainability
- Check for security implications
- Verify tests are adequate
- Ensure documentation is updated

## Release Process

Versioning is automated with [semantic-release](https://semantic-release.gitbook.io/semantic-release/), but releases
ship through **two channels**. Merging to `main` publishes to the dev channel; reaching consumers requires an explicit
promotion to the prod channel.

### Release channels

Each channel is a moving git tag that consumers pin instead of a fixed version:

| Channel | Tag | Moved by | GitHub Release |
|---------|-----|----------|----------------|
| dev | `dev-latest` | push to `main`, or `deploy=dev` dispatch | prerelease, not latest |
| prod | `prod-latest` | `deploy=prod` dispatch from a `vX.Y.Z` tag | marked latest |

```hcl
module "tenant" {
  source = "git::https://github.com/upwindsecurity/terraform-azurerm-onboarding.git//modules/tenant?ref=prod-latest"
}
```

Immutable `vX.Y.Z` tags are still created by semantic-release and are still the recommended pin for anything that needs
a fixed version. `dev-latest` and `prod-latest` are force-updated pointers layered on top; they carry no GitHub Release
of their own.

### Publishing to dev

1. **Conventional Commits**: Ensure all commits follow the [Conventional Commits](https://www.conventionalcommits.org/) format.
2. **Pull Request to `main`**: Open a pull request with your changes targeting the `main` branch.
3. **Merge the Pull Request**: Once approved and merged, the release workflow runs automatically.
4. **Automated Release**: If your commits warrant a new version, semantic-release calculates it, pushes the `vX.Y.Z`
   tag, and generates release notes. The workflow packages each module and publishes the GitHub Release as a
   **prerelease**, then moves `dev-latest` onto that commit. Nothing is marked latest, so consumers are unaffected.
5. **Release Branch and Pull Request**: The workflow then creates a release branch (e.g. `release-x.y.z`) and opens a
   pull request with the changelog update. Review and merge it to keep `main` current.

Commit types that carry no version bump (`ci:`, `test:`, `build:`) publish nothing and leave `dev-latest` where it is.

### Promoting to prod

Validate the change against a dev tenant using `?ref=dev-latest` first. Then promote:

```bash
gh workflow run release.yml --ref v1.19.0 -f deploy=prod
```

Or in the GitHub UI: **Actions → Release → Run workflow**, select the `vX.Y.Z` **tag** in *Use workflow from*, set
**deploy** to `prod`, and run.

The promotion run flips that existing release from prerelease to latest and moves `prod-latest` onto the tagged commit.

**Note:**

- Prod runs **must** start from a `vX.Y.Z` tag. Dispatching from a branch fails immediately, because `prod-latest` has
  to point at an immutable, already-released commit.
- To roll back, promote an earlier tag — dispatching `deploy=prod` from it moves `prod-latest` back, with no revert
  commit needed. This only works for tags cut after the two-channel release landed: `workflow_dispatch` runs the
  workflow file from the selected ref, and older tags contain a version that has no `deploy` input.
- A `deploy=dev` dispatch may run from any branch. It builds a `<version>-dev.<sha>` prerelease from unmerged code and
  moves `dev-latest`; it does not create a `vX.Y.Z` tag.

For more details, see `.github/workflows/release.yml`.

### Workflow Files

- `.github/workflows/ci.yml` - Continuous integration
- `.github/workflows/lint.yml` - Pull request title linting
- `.github/workflows/release.yml` - Release automation (dev and prod channels)
- `.github/workflows/discover.yml` - Reusable workflow listing modules and examples

### Continuous Integration

The project includes GitHub Actions workflows for:

- **Pull Request Validation**: Runs tests on pull requests
- **Release Management**: Automates semantic versioning and releases
- **Documentation**: Updates module documentation
- **Security Scanning**: Regular security vulnerability checks

## Troubleshooting

### Common Issues

**terraform-docs not updating**:

```bash
# Manually run terraform-docs
terraform-docs markdown table --output-file README.md modules/main/
```

**Pre-commit hooks failing**:

```bash
# Run pre-commit manually
pre-commit run --all-files

# Update hooks
pre-commit autoupdate
```

**Tests failing locally**:

```bash
# Clean up test artifacts
make clean

# Run tests step by step
make test-validate
make test-format
make test-lint
make test-security
```

## Useful Commands

```bash
# Format code
make fmt

# Validate configuration
make test-validate

# Run linting
make test-lint

# Generate documentation
make docs

# Run security scan
make test-security

# Clean up
make clean

# Initialize Terraform
make init

# Setup development environment
make setup

# Install required tools
make install-tools

# Run pre-commit hooks
make pre-commit

# Run all tests
make test-all
```

## Getting Help

If you have questions or need help:

- Check [existing issues](https://github.com/upwindsecurity/terraform-module/issues)
- Start a [Discussion](https://github.com/upwindsecurity/terraform-module/discussions)
- Review the [main README](README.md)

## Questions?

If you have questions about contributing, please:

1. Check this guide and the [README](README.md)
2. Search [existing issues](https://github.com/upwindsecurity/terraform-module/issues)
3. Create a new issue with the `question` label

Thank you for contributing! 🎉
