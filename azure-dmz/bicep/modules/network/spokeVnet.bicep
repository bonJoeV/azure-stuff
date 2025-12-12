@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Spoke VNet name.')
param vnetName string

@description('Spoke VNet address prefix.')
param addressPrefix string

@description('Subnet prefix for the workload subnet.')
param workloadSubnetPrefix string

@description('Subnet prefix for Private Endpoints.')
param privateEndpointSubnetPrefix string

@description('Tags applied to all resources where supported.')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'workload-subnet'
        properties: {
          addressPrefix: workloadSubnetPrefix
        }
      }
      {
        name: 'private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output spokeVnetId string = vnet.id
output workloadSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'workload-subnet')
output privateEndpointSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'private-endpoints')
