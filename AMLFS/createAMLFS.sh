#!/bin/bash

# Variables (can be passed as arguments or set as environment variables)
RETRY_LIMIT=${1:-5}  # Number of retries, default is 5
STORAGE_CAPACITY=${2:-32}  # Storage capacity in TB, default is 32 TB
RESOURCE_GROUP=${3:-"myResourceGroup"}  # Azure resource group, default is "myResourceGroup"
LUSTRE_NAME=${4:-"myLustreFS"}  # Azure Lustre file system name
SKU=${5:-"Standard_LRS"}  # Lustre SKU (Standard_LRS or Premium_LRS), default is Standard_LRS
LUSTRE_CONFIG_FILE=${6:-"lustre_configuration.json"}  # Lustre configuration file
LOCATION="eastus"  # Fixed region to South Central US
ZONE=${7:-1}  # Availability zone, default is zone 1
DELAY_BETWEEN_RETRIES=300  # 5 minutes (300 seconds) delay between retries

# Retry configuration
RETRY_COUNT=0
SUCCESS=0

# Function to create Managed Lustre file system
create_managed_lustre() {
    echo "Attempting to create Azure Managed Lustre: $LUSTRE_NAME in region $LOCATION with $STORAGE_CAPACITY TB, SKU $SKU, and Availability Zone $ZONE..."

    az amlfs create \
        --resource-group $RESOURCE_GROUP \
        --name $LUSTRE_NAME \
        --location $LOCATION \
        --sku $SKU \
        --storage-capacity $STORAGE_CAPACITY \
        --availability-zone $ZONE \
        --lustre-configuration $LUSTRE_CONFIG_FILE

    return $?
}

# Retry logic with backoff
while [ $RETRY_COUNT -lt $RETRY_LIMIT ]; do
    create_managed_lustre
    if [ $? -eq 0 ]; then
        echo "Azure Managed Lustre $LUSTRE_NAME created successfully!"
        SUCCESS=1
        break
    else
        echo "Failed to create Azure Managed Lustre. Retrying... ($RETRY_COUNT/$RETRY_LIMIT)"
        ((RETRY_COUNT++))
        if [ $RETRY_COUNT -lt $RETRY_LIMIT ]; then
            echo "Waiting for $DELAY_BETWEEN_RETRIES seconds (5 minutes) before retrying..."
            sleep $DELAY_BETWEEN_RETRIES  # 5-minute delay before retrying
        fi
    fi
done

# Check if creation was successful
if [ $SUCCESS -eq 0 ]; then
    echo "Failed to create Azure Managed Lustre after $RETRY_COUNT attempts."
    exit 1
else
    echo "Azure Managed Lustre $LUSTRE_NAME created successfully."
fi
