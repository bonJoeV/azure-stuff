@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Resource name prefix (will be combined with env + unique suffix).')
param namePrefix string = 'app'

@description('Subnet resource ID used for the Private Endpoint.')
param privateEndpointSubnetId string

@description('Optional static IP for the Private Endpoint NIC. Must be within the Private Endpoint subnet.')
param privateEndpointIp string = ''

@description('Private DNS zone resource ID for privatelink.azurewebsites.net.')
param privateDnsZoneId string

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var planName = 'asp-${namePrefix}-${environment}-${suffix}'
var siteName = 'app-${namePrefix}-${environment}-${suffix}'
var peName = 'pe-${siteName}'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 1
  }
  properties: {
    reserved: false
  }
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: siteName
  location: location
  tags: union(tags, {
    // Signals used by example policies; keep consistent with policy initiative.
    privateEndpointEnabled: 'true'
    approvedWafFronted: 'true'
  })
  properties: {
    serverFarmId: plan.id
    httpsOnly: false
    publicNetworkAccess: 'Disabled'
    siteConfig: {
      alwaysOn: true
    }
  }
}

resource pe 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: peName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    ipConfigurations: (privateEndpointIp != '') ? [
      {
        name: 'ipconfig1'
        properties: {
          groupId: 'sites'
          privateIPAddress: privateEndpointIp
        }
      }
    ] : null
    privateLinkServiceConnections: [
      {
        name: 'pls-${siteName}'
        properties: {
          privateLinkServiceId: site.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }
}

resource peZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: '${pe.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'azurewebsites'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output appServiceId string = site.id
output appServiceDefaultHostName string = site.properties.defaultHostName
output privateEndpointId string = pe.id
output privateEndpointIp string = (privateEndpointIp != '') ? privateEndpointIp : pe.properties.ipConfigurations[0].properties.privateIPAddress
