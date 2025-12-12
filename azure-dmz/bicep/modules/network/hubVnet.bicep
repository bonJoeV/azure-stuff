@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Hub VNet address prefix, e.g. 10.0.0.0/16')
param addressPrefix string

@description('Subnet prefixes object. Required keys: firewall, appGateway, sharedServices')
param subnetPrefixes object

@description('DDoS protection plan resource ID to associate to the hub VNet.')
param ddosPlanId string

@description('Tags applied to all resources where supported.')
param tags object = {}

var vnetName = 'vnet-hub-${environment}'

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

    // DDoS Network Protection is enabled by associating a plan.
    ddosProtectionPlan: {
      id: ddosPlanId
    }
    enableDdosProtection: true

    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: subnetPrefixes.firewall
        }
      }
      {
        name: 'appgw-subnet'
        properties: {
          addressPrefix: subnetPrefixes.appGateway
        }
      }
      {
        name: 'shared-svcs-subnet'
        properties: {
          addressPrefix: subnetPrefixes.sharedServices
        }
      }
    ]
  }
}

output hubVnetId string = vnet.id
output firewallSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'AzureFirewallSubnet')
output appGatewaySubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'appgw-subnet')
output sharedServicesSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, 'shared-svcs-subnet')
