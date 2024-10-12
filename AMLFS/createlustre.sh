#!/bin/bash

#-------------------------------------------
# Script: create_managed_lustre.sh
# Purpose: Deploy Azure Managed Lustre with retry logic and enhanced parameter handling
#-------------------------------------------

# Variables can be passed as arguments or set as environment variables

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --resource-group        Azure resource group (required)"
    echo "  -n, --lustre-name           Azure Managed Lustre filesystem name (required)"
    echo "  -s, --subscription-id       Azure subscription ID (required)"
    echo "  -v, --vnet-name             Virtual Network name (required)"
    echo "  -u, --subnet-name           Subnet name within the VNet (required)"
    echo "  -c, --storage-capacity      Storage capacity in TB (default: 48)"
    echo "  -k, --sku                   SKU tier (default: AMLFS-Durable-Premium-40)"
    echo "  -l, --location              Azure region (default: eastus)"
    echo "  -z, --zone                  Availability Zone (default: 1)"
    echo "  -m, --maintenance-day       Maintenance day of the week (default: friday)"
    echo "  -t, --maintenance-time      Maintenance time in UTC, HH:MM format (default: 22:00)"
    echo "  --retry-limit               Number of retries (default: 5)"
    echo "  --retry-delay               Delay between retries in seconds (default: 300)"
    echo "  -h, --help                  Display this help message"
    echo ""
    echo "SKU Info:"
    echo "  # SKU Info"
    echo "  # AMLFS-Durable-Premium-40   40 MBps     48 TB minimum    768 TB maximum    48 TB Increment"
    echo "  # AMLFS-Durable-Premium-125  125 MBps    16 TB minimum    128 TB maximum    16 TB Increment"
    echo "  # AMLFS-Durable-Premium-250  250 MBps    8 TB minimum     128 TB maximum    8 TB Increment"
    echo "  # AMLFS-Durable-Premium-500  500 MBps    4 TB minimum     128 TB maximum    4 TB Increment"
    echo ""
    echo "Example:"
    echo "  $0 -r myResourceGroup -n myLustreFS -s xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -v myVNet -u mySubnet"
    exit 1
}

# Default Values
DEFAULT_RETRY_LIMIT=5
DEFAULT_DELAY_BETWEEN_RETRIES=300  # 5 minutes (300 seconds) delay between retries

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -r|--resource-group) RESOURCE_GROUP="$2"; shift ;;
        -n|--lustre-name) LUSTRE_NAME="$2"; shift ;;
        -s|--subscription-id) SUBSCRIPTION_ID="$2"; shift ;;
        -v|--vnet-name) VNET_NAME="$2"; shift ;;
        -u|--subnet-name) SUBNET_NAME="$2"; shift ;;
        -c|--storage-capacity) STORAGE_CAPACITY="$2"; shift ;;
        -k|--sku) SKU="$2"; shift ;;
        -l|--location) LOCATION="$2"; shift ;;
        -z|--zone) ZONE="$2"; shift ;;
        -m|--maintenance-day) MAINTENANCE_DAY="$2"; shift ;;
        -t|--maintenance-time) MAINTENANCE_TIME="$2"; shift ;;
        --retry-limit) RETRY_LIMIT="$2"; shift ;;
        --retry-delay) DELAY_BETWEEN_RETRIES="$2"; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown parameter passed: $1"; usage ;;
    esac
    shift
done

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$LUSTRE_NAME" || -z "$SUBSCRIPTION_ID" || -z "$VNET_NAME" || -z "$SUBNET_NAME" ]]; then
    echo "Error: Missing required parameters."
    usage
fi

# Set default values if not provided
LOCATION=${LOCATION:-"eastus"}  # Fixed region to East US
STORAGE_CAPACITY=${STORAGE_CAPACITY:-48}
SKU=${SKU:-"AMLFS-Durable-Premium-40"}
ZONE=${ZONE:-1}  # Availability zone, default is zone 1
MAINTENANCE_DAY=${MAINTENANCE_DAY:-"friday"}   # Maintenance day of the week
MAINTENANCE_TIME=${MAINTENANCE_TIME:-"22:00"}  # Maintenance time in UTC (24-hour format)
RETRY_LIMIT=${RETRY_LIMIT:-$DEFAULT_RETRY_LIMIT}  # Number of retries, default is 5
DELAY_BETWEEN_RETRIES=${DELAY_BETWEEN_RETRIES:-$DEFAULT_DELAY_BETWEEN_RETRIES}  # Delay between retries

# Variables for VNet and Subnet names
# VNET_NAME and SUBNET_NAME are already set from arguments

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
    echo "  Resource Group: $RESOURCE_GROUP"
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
