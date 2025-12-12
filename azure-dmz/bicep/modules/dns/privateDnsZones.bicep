@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources (Private DNS zones are global but require a location value in ARM).')
param location string

@description('Array of Private DNS zone names to create (e.g., privatelink.vaultcore.azure.net).')
param zoneNames array

@description('Hub VNet resource ID to link to each zone for name resolution from hub services.')
param hubVnetId string

@description('Optional array of spoke VNet resource IDs to link to each zone.')
param spokeVnetIds array = []

@description('Tags applied to all resources where supported.')
param tags object = {}

resource zones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for zoneName in zoneNames: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource hubLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zoneName, i) in zoneNames: {
  name: '${zoneName}/link-hub-${environment}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: hubVnetId
    }
    registrationEnabled: false
  }
  dependsOn: [
    zones[i]
  ]
}]

resource spokeLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (zoneName, zoneIndex) in zoneNames: [for (spokeVnetId, spokeIndex) in spokeVnetIds: {
  name: '${zoneName}/link-spoke${spokeIndex}-${environment}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: spokeVnetId
    }
    registrationEnabled: false
  }
  dependsOn: [
    zones[zoneIndex]
  ]
}]]

output zoneIds array = [for z in zones: z.id]
output zoneIdByName object = { for (zoneName, i) in zoneNames: zoneName: zones[i].id }
