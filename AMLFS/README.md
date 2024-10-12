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
├── createlustre.sh             # Manual bash script
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

If you prefer not to use Terraform and GitHub Actions for deployment, you can utilize the [`creatlustre.sh`](./creatlustre.sh) script as an alternate deployment method. This script simplifies the setup process by directly using Azure CLI commands to create and configure an Azure Managed Lustre file system. The script also includes built-in retry and backoff logic to handle transient errors.

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
| [azurerm_managed_lustre_file_system.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/managed_lustre_file_system) | resource |
| [azurerm_resource_group.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_resource_group.rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [null_resource.create_lustre_fs](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.lustre_retry](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | n/a | `number` | `1` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | A list of availability zones where the Lustre file system will be deployed. E.g., ['1'], ['2'], etc. | `list(string)` | <pre>[<br>  "2"<br>]</pre> | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Enable backups for the Managed Lustre file system. | `bool` | `false` | no |
| <a name="input_delay_between_retries"></a> [delay\_between\_retries](#input\_delay\_between\_retries) | n/a | `number` | `300` | no |
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | Specifies the type of encryption to be used. Valid values are EncryptionAtRestWithPlatformKey and EncryptionAtRestWithCustomerKey. | `string` | `"EncryptionAtRestWithPlatformKey"` | no |
| <a name="input_location"></a> [location](#input\_location) | The Azure region to deploy the Lustre file system, e.g., West Europe. | `string` | `"West Europe"` | no |
| <a name="input_lustre_config_file"></a> [lustre\_config\_file](#input\_lustre\_config\_file) | n/a | `string` | `"./lustre_configuration.json"` | no |
| <a name="input_lustre_name"></a> [lustre\_name](#input\_lustre\_name) | The name of the Managed Lustre file system. | `string` | `"example-amlfs"` | no |
| <a name="input_maintenance_day"></a> [maintenance\_day](#input\_maintenance\_day) | Day of the week for the maintenance window. Valid values are Sunday through Saturday. | `string` | `"Friday"` | no |
| <a name="input_maintenance_time_utc"></a> [maintenance\_time\_utc](#input\_maintenance\_time\_utc) | Start time of the maintenance window in UTC, e.g., '22:00'. | `string` | `"22:00"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | The name of the resource group where the Lustre file system and related resources will be deployed. | `string` | `"example-resources"` | no |
| <a name="input_retry_delay_seconds"></a> [retry\_delay\_seconds](#input\_retry\_delay\_seconds) | Delay between retry attempts in seconds. | `number` | `180` | no |
| <a name="input_retry_limit"></a> [retry\_limit](#input\_retry\_limit) | Number of retry attempts in case of failure. | `number` | `5` | no |
| <a name="input_sku"></a> [sku](#input\_sku) | n/a | `string` | `"Standard_LRS"` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | The SKU of the Managed Lustre File System. Valid options are: AMLFS-Durable-Premium-40, AMLFS-Durable-Premium-125, AMLFS-Durable-Premium-250, and AMLFS-Durable-Premium-500. | `string` | `"AMLFS-Durable-Premium-250"` | no |
| <a name="input_storage_capacity"></a> [storage\_capacity](#input\_storage\_capacity) | n/a | `number` | `32` | no |
| <a name="input_storage_capacity_in_tb"></a> [storage\_capacity\_in\_tb](#input\_storage\_capacity\_in\_tb) | The storage capacity of the Lustre file system in Terabytes (TB). The valid range depends on the selected SKU. | `number` | `250` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | The address prefix for the subnet in CIDR format. | `string` | `"10.0.2.0/24"` | no |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | The name of the subnet within the virtual network where the Lustre file system will be placed. | `string` | `"example-subnet"` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | The address space for the virtual network in CIDR format. | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | The name of the virtual network that will contain the Lustre file system. | `string` | `"example-vnet"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lustre_file_system_id"></a> [lustre\_file\_system\_id](#output\_lustre\_file\_system\_id) | The ID of the Managed Lustre File System. |
| <a name="output_network_details"></a> [network\_details](#output\_network\_details) | The virtual network and subnet details where the Lustre File System resides. |
<!-- END_TF_DOCS -->
