targetScope = 'subscription'

@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources (e.g., eastus).')
param location string

@description('Name of the resource group hosting hub/DMZ resources.')
param hubResourceGroupName string

@description('Tags applied to all resources where supported.')
param tags object = {}

@description('Ingress option: frontDoor | appGateway')
@allowed([
  'frontDoor'
  'appGateway'
])
param ingressType string = 'frontDoor'

@description('Hub VNet address space.')
param hubVnetAddressPrefix string

@description('Subnet prefixes for hub subnets.')
param hubSubnetPrefixes object

@description('Log Analytics workspace SKU.')
param logAnalyticsSku string = 'PerGB2018'

@description('Private DNS zone list to create for Private Endpoints.')
param privateDnsZones array = [
  'privatelink.blob.core.windows.net'
  'privatelink.queue.core.windows.net'
  'privatelink.table.core.windows.net'
  'privatelink.file.core.windows.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.azurewebsites.net'
  'privatelink.database.windows.net'
]

@description('Firewall name (basename, environment is appended).')
param firewallBaseName string = 'azfw'

@description('Firewall Policy name (basename, environment is appended).')
param firewallPolicyBaseName string = 'azfwpol'

@description('DDoS plan name (basename, environment is appended).')
param ddosPlanBaseName string = 'ddos'

@description('Application Gateway name (basename, environment is appended).')
param appGatewayBaseName string = 'agw'

@description('Public IP name for Application Gateway (basename, environment is appended).')
param appGatewayPipBaseName string = 'pip-agw'

@description('Public IP name for Azure Firewall (basename, environment is appended).')
param firewallPipBaseName string = 'pip-azfw'

@description('Front Door profile name (basename, environment is appended).')
param frontDoorProfileBaseName string = 'afd'

resource hubRg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: hubResourceGroupName
  location: location
  tags: tags
}

module la 'modules/observability/logAnalytics.bicep' = {
  name: 'logAnalytics-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    sku: logAnalyticsSku
    tags: tags
  }
}

module network 'modules/network/hubVnet.bicep' = {
  name: 'hubVnet-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    addressPrefix: hubVnetAddressPrefix
    subnetPrefixes: hubSubnetPrefixes
    ddosPlanId: ddos.outputs.ddosPlanId
    tags: tags
  }
}

module ddos 'modules/network/ddosPlan.bicep' = {
  name: 'ddos-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    ddosPlanBaseName: ddosPlanBaseName
    tags: tags
  }
}

module dns 'modules/dns/privateDnsZones.bicep' = {
  name: 'privateDns-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    zoneNames: privateDnsZones
    hubVnetId: network.outputs.hubVnetId
    tags: tags
  }
}

module firewall 'modules/security/firewallPremium.bicep' = {
  name: 'firewall-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    firewallBaseName: firewallBaseName
    firewallPipBaseName: firewallPipBaseName
    firewallPolicyBaseName: firewallPolicyBaseName
    firewallSubnetId: network.outputs.firewallSubnetId
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    tags: tags
  }
}

module appGw 'modules/ingress/appGatewayWaf.bicep' = if (ingressType == 'appGateway') {
  name: 'appGateway-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    appGatewayBaseName: appGatewayBaseName
    publicIpBaseName: appGatewayPipBaseName
    appGatewaySubnetId: network.outputs.appGatewaySubnetId
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    tags: tags
  }
}

module afd 'modules/ingress/frontDoor.bicep' = if (ingressType == 'frontDoor') {
  name: 'frontDoor-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    profileBaseName: frontDoorProfileBaseName
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    tags: tags

    // NOTE: This module intentionally scaffolds Front Door. You will still need to wire an origin
    // (e.g., Firewall Public IP for DNAT pattern, or a supported private origin using Private Link).
  }
}

output hubVnetId string = network.outputs.hubVnetId
output firewallId string = firewall.outputs.firewallId
output logAnalyticsWorkspaceId string = la.outputs.workspaceId
