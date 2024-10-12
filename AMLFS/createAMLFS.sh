#!/bin/bash

# Variables (can be passed as arguments or set as environment variables)
RETRY_LIMIT=${1:-5}  # Number of retries, default is 5
DELAY_BETWEEN_RETRIES=${2:-300} # 5 minutes (300 seconds) delay between retries

RESOURCE_GROUP=${3:-"storagetesting01"}  # Azure resource group, default is "storagetesting01"
LUSTRE_NAME=${4:-"myLustreFS"}  # Azure Lustre file system name
LOCATION="eastus"  # Fixed region to East US

# SKU Info
# AMLFS-Durable-Premium-40	40 MBps	    48 TB minimum	768 TB	maximum    48 TB Increment
# AMLFS-Durable-Premium-125	125 MBps	16 TB minimum	128 TB	maximum    16 TB Increment
# AMLFS-Durable-Premium-250	250 MBps	8 TB minimum	128 TB	maximum    8 TB Increment
# AMLFS-Durable-Premium-500	500 MBps	4 TB minimum	128 TB	maximum    4 TB Increment
STORAGE_CAPACITY=${5:-48}
SKU=${6:-"AMLFS-Durable-Premium-40"}

ZONE=${7:-1}  # Availability zone, default is zone 1

# Variables for maintenance window
MAINTENANCE_DAY=${8:-"friday"}   # Maintenance day of the week
MAINTENANCE_TIME=${9:-"22:00"}   # Maintenance time in UTC (24-hour format)

# Variable for subscription ID
SUBSCRIPTION_ID=${10:-"56481b06-c4a3-441a-a090-1ebce6bc3642"}  # Your subscription ID

# Variables for VNet and Subnet names
VNET_NAME=${11:-"lustre-vnet"}    # Virtual network name
SUBNET_NAME=${12:-"default"}      # Subnet name

# Construct the FILESYSTEM_SUBNET using subscription ID, resource group, VNet, and subnet
FILESYSTEM_SUBNET="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$VNET_NAME/subnets/$SUBNET_NAME"

# Set the Azure CLI to use the specified subscription
echo "Setting Azure CLI to use subscription ID: $SUBSCRIPTION_ID"
az account set --subscription "$SUBSCRIPTION_ID"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set Azure CLI to use subscription ID: $SUBSCRIPTION_ID"
    exit 1
fi

# Retry configuration
RETRY_COUNT=0
SUCCESS=0

# Function to create Managed Lustre file system
create_managed_lustre() {
    echo "Attempting to create Azure Managed Lustre: $LUSTRE_NAME in region $LOCATION with the following settings:"
    echo "  Storage Capacity: $STORAGE_CAPACITY TB"
    echo "  SKU: $SKU"
    echo "  Availability Zone: $ZONE"
    echo "  Maintenance Window: $MAINTENANCE_DAY at $MAINTENANCE_TIME UTC"
    echo "  Filesystem Subnet: $FILESYSTEM_SUBNET"

    az amlfs create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$LUSTRE_NAME" \
        --location "$LOCATION" \
        --sku "$SKU" \
        --storage-capacity "$STORAGE_CAPACITY" \
        --zones "$ZONE" \
        --maintenance-window "{\"dayOfWeek\":\"$MAINTENANCE_DAY\",\"timeOfDayUtc\":\"$MAINTENANCE_TIME\"}" \
        --filesystem-subnet "$FILESYSTEM_SUBNET"

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
        echo "Failed to create Azure Managed Lustre. Retrying... ($((RETRY_COUNT + 1))/$RETRY_LIMIT)"
        ((RETRY_COUNT++))
        if [ $RETRY_COUNT -lt $RETRY_LIMIT ]; then
            echo "Waiting for $DELAY_BETWEEN_RETRIES seconds before retrying..."
            sleep $DELAY_BETWEEN_RETRIES
        fi
    fi
done

# Check if creation was successful
if [ $SUCCESS -eq 0 ]; then
    echo "Error: Failed to create Azure Managed Lustre after $RETRY_COUNT attempts."
    exit 1
else
    echo "Azure Managed Lustre $LUSTRE_NAME created successfully."
fi
