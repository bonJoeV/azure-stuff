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

// Force spoke egress back through firewall to preserve symmetric return for DNAT.
resource spokeUdr 'Microsoft.Network/routeTables@2023-11-01' = {
  name: 'rt-spoke-egress-${environment}'
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

resource spokePeSubnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'vnet-spoke-app1-${environment}/private-endpoints'
  properties: {
    addressPrefix: spokePrivateEndpointSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    routeTable: {
      id: spokeUdr.id
    }
  }
  dependsOn: [
    spokeNet
  ]
}

resource spokeWorkloadSubnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: 'vnet-spoke-app1-${environment}/workload-subnet'
  properties: {
    addressPrefix: spokeWorkloadSubnetPrefix
    routeTable: {
      id: spokeUdr.id
    }
  }
  dependsOn: [
    spokeNet
  ]
}

module app '../../modules/workload/appServiceWithPrivateEndpoint.bicep' = {
  name: 'app1-${environment}'
  scope: spokeRg
  params: {
    environment: environment
    location: location
    namePrefix: 'app1'
    privateEndpointSubnetId: spokePeSubnetAssoc.id
    privateEndpointIp: appPrivateEndpointIp
    privateDnsZoneId: dns.outputs.zoneIdByName['privatelink.azurewebsites.net']
    tags: tags
  }
}

var firewallPublicIp = reference(fw.outputs.firewallPublicIpId, '2023-11-01').ipAddress

// DNAT: Firewall public IP:80 -> App Service Private Endpoint IP:80
module nat '../../modules/security/firewallPolicyRulesNat.bicep' = {
  name: 'fw-nat-${environment}'
  scope: hubRg
  params: {
    firewallPolicyId: fw.outputs.firewallPolicyId
    ruleCollectionGroupName: 'rcg-ingress'
    priority: 200
    natRules: [
      {
        name: 'dnat-app1-http'
        ruleType: 'NatRule'
        ipProtocols: [
          'TCP'
        ]
        sourceAddresses: [
          '*'
        ]
        destinationAddresses: [
          firewallPublicIp
        ]
        destinationPorts: [
          '80'
        ]
        translatedAddress: app.outputs.privateEndpointIp
        translatedPort: '80'
      }
    ]
  }
}

// Front Door (AFD) routes to the firewall public IP as an origin.
module afd '../../modules/ingress/frontDoor.bicep' = {
  name: 'afd-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    profileBaseName: 'afd'
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    enableSampleOnboarding: true
    sampleOriginHostName: firewallPublicIp
    sampleOriginHttpPort: 80
    tags: tags
  }
}

output firewallPublicIp string = firewallPublicIp
output privateEndpointIp string = app.outputs.privateEndpointIp
output frontDoorEndpointId string = afd.outputs.frontDoorEndpointId
