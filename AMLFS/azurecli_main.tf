provider "azurerm" {
  features {}
}

# Define variables
variable "resource_group_name" {
  default = "myResourceGroup"
}

variable "location" {
  default = "southcentralus"
}

variable "lustre_name" {
  default = "myLustreFS"
}

variable "sku" {
  default = "Standard_LRS"
}

variable "storage_capacity" {
  default = 32
}

variable "lustre_config_file" {
  default = "./lustre_configuration.json"
}

variable "retry_limit" {
  default = 5
}

variable "delay_between_retries" {
  default = 300 # 5 minutes in seconds
}

variable "availability_zone" {
  default = 1 # Modify this based on the available zones for your region
}

# Define the resource group for the Lustre deployment
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create the Azure Managed Lustre file system
resource "azurerm_lustre_file_system" "lustre" {
  name                = var.lustre_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = var.sku
  storage_capacity    = var.storage_capacity
  zone                = var.availability_zone
}

# Using null_resource to run Azure CLI commands for creating Lustre
resource "null_resource" "create_lustre_fs" {
  provisioner "local-exec" {
    command = <<EOT
      #!/bin/bash
      RETRY_COUNT=0
      SUCCESS=0

      create_managed_lustre() {
        echo "Attempting to create Azure Managed Lustre: ${var.lustre_name} in region ${var.location} with ${var.storage_capacity} TB, SKU ${var.sku}, and Availability Zone ${var.availability_zone}..."
        az lustre create \
          --resource-group ${var.resource_group_name} \
          --name ${var.lustre_name} \
          --location ${var.location} \
          --sku ${var.sku} \
          --storage-capacity ${var.storage_capacity} \
          --availability-zone ${var.availability_zone} \
          --lustre-configuration ${var.lustre_config_file}
        return $?
      }

      while [ $RETRY_COUNT -lt ${var.retry_limit} ]; do
        create_managed_lustre
        if [ $? -eq 0 ]; then
          echo "Azure Managed Lustre ${var.lustre_name} created successfully!"
          SUCCESS=1
          break
        else
          echo "Failed to create Azure Managed Lustre. Retrying... ($RETRY_COUNT/${var.retry_limit})"
          ((RETRY_COUNT++))
          if [ $RETRY_COUNT -lt ${var.retry_limit} ]; then
            echo "Waiting for ${var.delay_between_retries} seconds (5 minutes) before retrying..."
            sleep ${var.delay_between_retries}
          fi
        fi
      done

      if [ $SUCCESS -eq 0 ]; then
        echo "Failed to create Azure Managed Lustre after $RETRY_COUNT attempts."
        exit 1
      fi
    EOT
    interpreter = ["/bin/bash", "-c"]
  }

  depends_on = [
    azurerm_resource_group.rg
  ]
}
