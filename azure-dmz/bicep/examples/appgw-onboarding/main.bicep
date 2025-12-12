targetScope = 'subscription'

@description('Environment name (e.g., dev).')
param environment string = 'dev'

@description('Azure region for regional resources.')
param location string = 'eastus'

@description('Tags applied to all resources.')
param tags object = {
  owner: 'PlatformTeam'
  service: 'ingress'
  environment: environment
}

@description('Hub resource group name.')
param hubResourceGroupName string = 'rg-hub-${environment}'

@description('Spoke resource group name.')
param spokeResourceGroupName string = 'rg-spoke-app1-${environment}'

@description('Hub VNet address space.')
param hubVnetAddressPrefix string = '10.0.0.0/16'

@description('Hub subnets.')
param hubSubnetPrefixes object = {
  firewall: '10.0.0.0/24'
  appGateway: '10.0.1.0/24'
  sharedServices: '10.0.2.0/24'
}

@description('Static private IP for Azure Firewall in AzureFirewallSubnet (must be within firewall subnet).')
param firewallPrivateIp string = '10.0.0.4'

@description('Spoke VNet address space.')
param spokeVnetAddressPrefix string = '10.10.0.0/16'

@description('Spoke workload subnet prefix.')
param spokeWorkloadSubnetPrefix string = '10.10.1.0/24'

@description('Spoke private endpoints subnet prefix.')
param spokePrivateEndpointSubnetPrefix string = '10.10.2.0/24'

@description('Static private IP for the App Service Private Endpoint (must be within spoke private endpoints subnet).')
param appPrivateEndpointIp string = '10.10.2.10'

@description('Sample public hostname used in App Gateway HTTP listener host header match.')
param samplePublicHostName string = 'app1.example.com'

resource hubRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: hubResourceGroupName
  location: location
  tags: tags
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: spokeResourceGroupName
  location: location
  tags: tags
}

module la '../../modules/observability/logAnalytics.bicep' = {
  name: 'law-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    tags: tags
  }
}

module ddos '../../modules/network/ddosPlan.bicep' = {
  name: 'ddos-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    ddosPlanBaseName: 'ddos'
    tags: tags
  }
}

module hubNet '../../modules/network/hubVnet.bicep' = {
  name: 'hubNet-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    addressPrefix: hubVnetAddressPrefix
    subnetPrefixes: hubSubnetPrefixes
    ddosPlanId: ddos.outputs.ddosPlanId
    tags: union(tags, {
      networkRole: 'hub'
    })
  }
}

module spokeNet '../../modules/network/spokeVnet.bicep' = {
  name: 'spokeNet-${environment}'
  scope: spokeRg
  params: {
    environment: environment
    location: location
    vnetName: 'vnet-spoke-app1-${environment}'
    addressPrefix: spokeVnetAddressPrefix
    workloadSubnetPrefix: spokeWorkloadSubnetPrefix
    privateEndpointSubnetPrefix: spokePrivateEndpointSubnetPrefix
    tags: tags
  }
}

module peering '../../modules/network/vnetPeering.bicep' = {
  name: 'peer-hub-spoke-${environment}'
  scope: hubRg
  params: {
    hubVnetId: hubNet.outputs.hubVnetId
    hubVnetName: 'vnet-hub-${environment}'
    spokeVnetId: spokeNet.outputs.spokeVnetId
    spokeVnetName: 'vnet-spoke-app1-${environment}'
    allowForwardedTraffic: true
  }
}

module dns '../../modules/dns/privateDnsZones.bicep' = {
  name: 'dns-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    zoneNames: [
      'privatelink.azurewebsites.net'
    ]
    hubVnetId: hubNet.outputs.hubVnetId
    spokeVnetIds: [
      spokeNet.outputs.spokeVnetId
    ]
    tags: tags
  }
}

module fw '../../modules/security/firewallPremium.bicep' = {
  name: 'fw-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    firewallBaseName: 'azfw'
    firewallPipBaseName: 'pip-azfw'
    firewallPolicyBaseName: 'azfwpol'
    firewallSubnetId: hubNet.outputs.firewallSubnetId
    firewallPrivateIp: firewallPrivateIp
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    tags: tags
  }
}

// Route App Gateway subnet egress via firewall to ensure AppGw -> backend flows traverse firewall.
resource appGwUdr 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'rt-appgw-egress-${environment}'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'default-to-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fw.outputs.firewallPrivateIp
        }
      }
    ]
  }
}

resource appGwSubnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'vnet-hub-${environment}/appgw-subnet'
  properties: {
    addressPrefix: hubSubnetPrefixes.appGateway
    routeTable: {
      id: appGwUdr.id
    }
  }
  dependsOn: [
    hubNet
  ]
}

module appGw '../../modules/ingress/appGatewayWaf.bicep' = {
  name: 'agw-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    appGatewayBaseName: 'agw'
    publicIpBaseName: 'pip-agw'
    appGatewaySubnetId: appGwSubnetAssoc.id
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    enableSampleOnboarding: true
    sampleListenerHostName: samplePublicHostName
    // Backend FQDN resolves via privatelink.azurewebsites.net to the Private Endpoint IP
    sampleBackendFqdn: app.outputs.appServiceDefaultHostName
    tags: tags
  }
}

module app '../../modules/workload/appServiceWithPrivateEndpoint.bicep' = {
  name: 'app1-${environment}'
  scope: spokeRg
  params: {
    environment: environment
    location: location
    namePrefix: 'app1'
    privateEndpointSubnetId: spokeNet.outputs.privateEndpointSubnetId
    privateEndpointIp: appPrivateEndpointIp
    privateDnsZoneId: dns.outputs.zoneIdByName['privatelink.azurewebsites.net']
    tags: tags
  }
}

output appGatewayPublicIp string = reference(appGw.outputs.appGatewayPublicIpId, '2023-11-01').ipAddress
output appServiceHostName string = app.outputs.appServiceDefaultHostName
output appGatewayPublicIpId string = appGw.outputs.appGatewayPublicIpId
