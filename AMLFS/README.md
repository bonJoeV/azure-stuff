# Azure Managed Lustre Deployment with Terraform and GitHub Actions

![Terraform Version](https://img.shields.io/badge/Terraform-1.x-blue)
![License](https://img.shields.io/badge/license-MIT-blue)
![License](https://img.shields.io/badge/Built_by-bonJoeV-blue)

This repository automates the deployment of an **Azure Managed Lustre** file system using **Terraform** and **GitHub Actions**. It includes Terraform scripts, a GitHub Actions workflow for CI/CD, and a Lustre configuration file.

Azure Managed Lustre is ideal for workloads that require low-latency, high-throughput storage, such as big data analytics, AI/ML model training, and media processing.

## Project Structure

```plaintext
.
├── .github
│   └── workflows
│       └── terraform.yml       # GitHub Actions workflow for CI/CD
├── CONTRIBUTING.md             # Contribution information
├── LICENSE                     # MIT License file
├── README.md                   # Readme file with project details and setup instructions
├── createAMLFS.sh              # Manual bash script
├── lustre_configuration.json   # Configuration file for Azure Managed Lustre
└── main.tf                     # Terraform script to deploy Azure Managed Lustre
```

## Prerequisites

1. **Azure Subscription**: Ensure you have an active Azure account. If you don’t have one, you can create a free account at [Azure Free Account](https://azure.microsoft.com/en-us/free/).
2. **Service Principal**: You need an Azure Service Principal with sufficient permissions to deploy resources. Follow the [official Azure documentation](https://learn.microsoft.com/en-us/cli/azure/create-an-azure-service-principal-azure-cli) to create a service principal.
3. **Terraform**: Install Terraform (version 1.x or higher) on your local machine. Refer to [Terraform Install Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli) for detailed instructions. Alternatively, the CI/CD pipeline provided in this repository will handle Terraform installation automatically.

## Setup Instructions

### 1. Create GitHub Secrets

In your GitHub repository, add the following secrets under **Settings > Secrets and variables > Actions**:

- `ARM_CLIENT_ID`: Azure Service Principal Client ID.
- `ARM_CLIENT_SECRET`: Azure Service Principal Client Secret.
- `ARM_TENANT_ID`: Azure Tenant ID.
- `ARM_SUBSCRIPTION_ID`: Azure Subscription ID.

Optionally, you can store these credentials as a single **`AZURE_CREDENTIALS`** secret as a JSON object.

### 2. Modify Terraform Variables

In the `main.tf`, you can adjust the following variables based on your deployment needs:

| Variable              | Description                                | Default Value         |
|-----------------------|--------------------------------------------|-----------------------|
| `resource_group_name`  | The name of the Azure resource group       | `myResourceGroup`     |
| `location`             | Azure region for the resources             | `southcentralus`      |
| `lustre_name`          | Name of the Lustre file system             | `myLustreFS`          |
| `sku`                  | SKU for the Lustre file system             | `Standard_LRS`        |
| `storage_capacity`     | Storage capacity in TB                     | `32`                  |
| `lustre_config_file`   | Path to the Lustre configuration JSON file | `./lustre_configuration.json` |
| `retry_limit`          | Number of retry attempts                   | `5`                   |
| `delay_between_retries`| Delay between retries in seconds (5 mins)  | `300`                 |

### 3. GitHub Actions Workflow

The **GitHub Actions** workflow (`terraform.yml`) will automatically run on a push to the `main` branch, or you can manually trigger it. The workflow will:

- Authenticate to Azure using a Service Principal.
- Initialize Terraform and set up the backend for storing state in Azure.
- Deploy the Azure Managed Lustre file system.
- Use retry logic in case of transient deployment issues.

You can monitor the deployment process in the **Actions** tab of your GitHub repository.

### 4. Run the Deployment

1. Clone this repository to your local machine.
2. Push the repository to GitHub.
3. The GitHub Actions pipeline will automatically trigger on a push to the `main` branch.

You can monitor the deployment process in the **Actions** tab of your GitHub repository.

### Alternate Deployment Option: `createAMLFS.sh`

If you prefer not to use Terraform and GitHub Actions for deployment, you can utilize the [`createAMLFS.sh`](./createAMLFS.sh) script as an alternate deployment method. This script simplifies the setup process by directly using Azure CLI commands to create and configure an Azure Managed Lustre file system. The script also includes built-in retry and backoff logic to handle transient errors.

To run the script:
1. Ensure you have the Azure CLI installed (`az` command).
2. Modify the script to include your Azure credentials and configuration preferences.
3. Run the script using the following command:
   ```bash
   bash createAMLFS.sh
### Security Best Practices

- Use **Azure Key Vault** to store and manage secrets securely, such as your Azure Service Principal credentials.
- Regularly rotate your Service Principal credentials to maintain a secure environment.
- Limit the permissions of your Service Principal to only those necessary for the deployment process.

### Troubleshooting

- **Authentication Errors**: Ensure that the Azure Service Principal credentials are correctly set up as GitHub secrets (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`). Verify that the Service Principal has the necessary permissions in your Azure subscription.
- **Insufficient Storage Capacity Error**: Check the `storage_capacity` setting in the `main.tf` file to ensure that the requested capacity is within the limits for the selected region and SKU.
- **Deployment Fails with Retry Limit Reached**: If the retry limit is reached, check the Azure CLI logs for possible issues with the Lustre configuration or resource availability in the specified region. Modify the `retry_limit` or `delay_between_retries` in the Terraform configuration to adjust the retry logic.

### Cost Considerations

Deploying an Azure Managed Lustre file system may incur costs depending on the chosen SKU, storage capacity, and region. Be sure to review the [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/) to estimate your monthly costs based on your selected configuration.

For testing and development purposes, consider using a smaller capacity and the `Standard_LRS` SKU to minimize expenses.

### Example Deployment

Here’s a sample configuration for `main.tf`:

```hcl
variable "resource_group_name" {
  default = "example-lustre-rg"
}

variable "location" {
  default = "eastus"
}

variable "lustre_name" {
  default = "example-lustre"
}

variable "sku" {
  default = "Standard_LRS"
}

variable "storage_capacity" {
  default = 16  # 16 TB
}
```

This example will deploy a 16 TB Lustre file system in the `eastus` region, using the `Standard_LRS` storage SKU for lower cost.

### Resources

- [Azure Managed Lustre Documentation](https://learn.microsoft.com/en-us/azure/azure-managed-lustre/amlfs-overview)
- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_null"></a> [null](#provider\_null) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_lustre_file_system.lustre](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lustre_file_system) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [null_resource.create_lustre_fs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | n/a | `number` | `1` | no |
| <a name="input_delay_between_retries"></a> [delay\_between\_retries](#input\_delay\_between\_retries) | n/a | `number` | `300` | no |
| <a name="input_location"></a> [location](#input\_location) | n/a | `string` | `"southcentralus"` | no |
| <a name="input_lustre_config_file"></a> [lustre\_config\_file](#input\_lustre\_config\_file) | n/a | `string` | `"./lustre_configuration.json"` | no |
| <a name="input_lustre_name"></a> [lustre\_name](#input\_lustre\_name) | n/a | `string` | `"myLustreFS"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Define variables | `string` | `"myResourceGroup"` | no |
| <a name="input_retry_limit"></a> [retry\_limit](#input\_retry\_limit) | n/a | `number` | `5` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | n/a | `string` | `"Standard_LRS"` | no |
| <a name="input_storage_capacity"></a> [storage\_capacity](#input\_storage\_capacity) | n/a | `number` | `32` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
