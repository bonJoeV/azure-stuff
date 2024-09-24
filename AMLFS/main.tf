provider "azurerm" {
  features {}
}

# Note- I just found that azurerm_managed_lustre_file_system is available! woot! 

##############################################################
# Variables Section
##############################################################

# Resource Group Name for Lustre Deployment
variable "resource_group_name" {
  description = "The name of the resource group where the Lustre file system and related resources will be deployed."
  default     = "example-resources"
}

# Azure Region where the Lustre file system will be deployed
variable "location" {
  description = "The Azure region to deploy the Lustre file system, e.g., West Europe."
  default     = "West Europe"
}

# Lustre File System Name
variable "lustre_name" {
  description = "The name of the Managed Lustre file system."
  default     = "example-amlfs"
}

# SKU Name for Lustre File System
variable "sku_name" {
  description = "The SKU of the Managed Lustre File System. Valid options are: AMLFS-Durable-Premium-40, AMLFS-Durable-Premium-125, AMLFS-Durable-Premium-250, and AMLFS-Durable-Premium-500."
  default     = "AMLFS-Durable-Premium-250"
}

# Storage Capacity for Lustre File System in TB
variable "storage_capacity_in_tb" {
  description = "The storage capacity of the Lustre file system in Terabytes (TB). The valid range depends on the selected SKU."
  default     = 250
}

# Availability Zones for Lustre File System
variable "availability_zones" {
  description = "A list of availability zones where the Lustre file system will be deployed. E.g., ['1'], ['2'], etc."
  type        = list(string)
  default     = ["2"]
}

# Virtual Network and Subnet Configuration
variable "vnet_name" {
  description = "The name of the virtual network that will contain the Lustre file system."
  default     = "example-vnet"
}

variable "vnet_address_space" {
  description = "The address space for the virtual network in CIDR format."
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "The name of the subnet within the virtual network where the Lustre file system will be placed."
  default     = "example-subnet"
}

variable "subnet_address_prefix" {
  description = "The address prefix for the subnet in CIDR format."
  default     = "10.0.2.0/24"
}

# Backup Option
variable "backup_enabled" {
  description = "Enable backups for the Managed Lustre file system."
  default     = false
}

# Encryption Option
variable "encryption_type" {
  description = "Specifies the type of encryption to be used. Valid values are EncryptionAtRestWithPlatformKey and EncryptionAtRestWithCustomerKey."
  default     = "EncryptionAtRestWithPlatformKey"
}

# Maintenance Window Configuration
variable "maintenance_day" {
  description = "Day of the week for the maintenance window. Valid values are Sunday through Saturday."
  default     = "Friday"
}

variable "maintenance_time_utc" {
  description = "Start time of the maintenance window in UTC, e.g., '22:00'."
  default     = "22:00"
}

# Retry Parameters
variable "retry_limit" {
  description = "Number of retry attempts in case of failure."
  default     = 5
}

variable "retry_delay_seconds" {
  description = "Delay between retry attempts in seconds."
  default     = 180  # 3 minutes
}

##############################################################
# Resource Group Definition
##############################################################

# Create the Resource Group for Lustre
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

##############################################################
# Networking Configuration (Virtual Network and Subnet)
##############################################################

# Create the Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = var.vnet_name
  address_space       = [var.vnet_address_space]
  location            = var.location
  resource_group_name = azurerm_resource_group.example.name
}

# Create the Subnet
resource "azurerm_subnet" "example" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [var.subnet_address_prefix]
}

##############################################################
# Managed Lustre File System with Retry Logic
##############################################################

# Define a null_resource to handle retry logic
resource "null_resource" "lustre_retry" {
  provisioner "local-exec" {
    command = <<EOT
      #!/bin/bash
      RETRY_LIMIT=${var.retry_limit}
      RETRY_DELAY=${var.retry_delay_seconds}
      RETRY_COUNT=0
      SUCCESS=0

      while [ $RETRY_COUNT -lt $RETRY_LIMIT ]; do
        terraform apply -target=azurerm_managed_lustre_file_system.example -auto-approve

        if [ $? -eq 0 ]; then
          echo "Lustre file system created successfully!"
          SUCCESS=1
          break
        else
          echo "Failed to create Lustre file system. Retrying in $RETRY_DELAY seconds..."
          RETRY_COUNT=$((RETRY_COUNT+1))
          sleep $RETRY_DELAY
        fi
      done

      if [ $SUCCESS -ne 1 ]; then
        echo "Failed to create Lustre file system after $RETRY_COUNT attempts."
        exit 1
      fi
    EOT
  }
}

# Actual creation of the Lustre File System (which can be retried)
resource "azurerm_managed_lustre_file_system" "example" {
  name                   = var.lustre_name
  resource_group_name    = azurerm_resource_group.example.name
  location               = var.location
  sku_name               = var.sku_name
  subnet_id              = azurerm_subnet.example.id
  storage_capacity_in_tb = var.storage_capacity_in_tb
  zones                  = var.availability_zones

  # Optional Parameters
  backup_enabled         = var.backup_enabled
  encryption_type        = var.encryption_type

  # Maintenance Window block
  maintenance_window {
    day_of_week     = var.maintenance_day
    time_of_day_utc = var.maintenance_time_utc
  }

  # Tags (optional)
  tags = {
    Environment = "Production"
    Project     = "LustreHPC"
  }
}

##############################################################
# Outputs for Reference
##############################################################

# Output the Lustre File System ID
output "lustre_file_system_id" {
  description = "The ID of the Managed Lustre File System."
  value       = azurerm_managed_lustre_file_system.example.id
}

# Output the Virtual Network and Subnet Information
output "network_details" {
  description = "The virtual network and subnet details where the Lustre File System resides."
  value = {
    vnet_id   = azurerm_virtual_network.example.id
    subnet_id = azurerm_subnet.example.id
  }
}
