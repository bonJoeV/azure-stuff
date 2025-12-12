@description('Hub VNet resource ID.')
param hubVnetId string

@description('Hub VNet name (for peering child resource IDs).')
param hubVnetName string

@description('Spoke VNet resource ID.')
param spokeVnetId string

@description('Spoke VNet name (for peering child resource IDs).')
param spokeVnetName string

@description('Allow forwarded traffic across peering (required for transitive forwarding scenarios).')
param allowForwardedTraffic bool = true

@description('Allow gateway transit from hub (optional).')
param allowGatewayTransit bool = false

@description('Use remote gateways on spoke (optional).')
param useRemoteGateways bool = false

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${hubVnetName}/to-${spokeVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: spokeVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: false
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-11-01' = {
  name: '${spokeVnetName}/to-${hubVnetName}'
  properties: {
    remoteVirtualNetwork: {
      id: hubVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: false
    useRemoteGateways: useRemoteGateways
  }
}

output hubPeeringId string = hubToSpoke.id
output spokePeeringId string = spokeToHub.id
