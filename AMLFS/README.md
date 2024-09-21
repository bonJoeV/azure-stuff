# Azure Managed Lustre Deployment with Terraform and GitHub Actions

This repository automates the deployment of an **Azure Managed Lustre** file system using **Terraform** and **GitHub Actions**. It includes Terraform scripts, a GitHub Actions workflow for CI/CD, and a Lustre configuration file.

## Project Structure
```
.
├── main.tf                    # Terraform script to deploy Azure Managed Lustre
├── .github
│   └── workflows
│       └── terraform.yml       # GitHub Actions workflow for CI/CD
├── lustre_configuration.json   # Configuration file for Azure Managed Lustre
├── README.md                   # Readme file with project details and setup instructions
└── LICENSE                     # MIT License file
```

## Prerequisites

1. **Azure Subscription**: Ensure you have an Azure account.
2. **Service Principal**: Create an Azure Service Principal with the necessary permissions for deployment.
3. **Terraform**: Install Terraform on your local machine or use the CI/CD pipeline to handle it.

## Setup Instructions

### 1. Create GitHub Secrets

In your GitHub repository, add the following secrets under **Settings > Secrets and variables > Actions**:

- `ARM_CLIENT_ID`: Azure Service Principal Client ID.
- `ARM_CLIENT_SECRET`: Azure Service Principal Client Secret.
- `ARM_TENANT_ID`: Azure Tenant ID.
- `ARM_SUBSCRIPTION_ID`: Azure Subscription ID.

Optionally, you can store these credentials as a single **`AZURE_CREDENTIALS`** secret as a JSON object.

### 2. Modify Terraform Variables

In the `main.tf`, you can adjust the variables such as:

- **`resource_group_name`**: Name of the Azure Resource Group.
- **`location`**: Azure region (e.g., `southcentralus`).
- **`lustre_name`**: Name of the Lustre file system.
- **`sku`**: Storage SKU (`Standard_LRS` or `Premium_LRS`).
- **`storage_capacity`**: Size of the Lustre file system in TB.

### 3. GitHub Actions Workflow

The **GitHub Actions** workflow (`terraform.yml`) will automatically run on a push to the `main` branch, or you can manually trigger it. The workflow will:

- Authenticate to Azure using a Service Principal.
- Initialize Terraform and set up the backend for storing state in Azure.
- Deploy the Azure Managed Lustre file system.

### 4. Run the Deployment

1. Clone this repository to your local machine.
2. Push the repository to GitHub.
3. The GitHub Actions pipeline will automatically trigger on a push to the `main` branch.

You can monitor the deployment process in the **Actions** tab of your GitHub repository.

### Alternate Deployment with retry and backoff

- **[createAMLFS.sh](createAMLFS.sh)**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.