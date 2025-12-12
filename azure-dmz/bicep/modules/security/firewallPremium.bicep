@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Firewall base name (environment + unique suffix are added).')
param firewallBaseName string

@description('Firewall public IP base name (environment + unique suffix are added).')
param firewallPipBaseName string

@description('Firewall Policy base name (environment + unique suffix are added).')
param firewallPolicyBaseName string

@description('Resource ID of the AzureFirewallSubnet in the hub VNet.')
param firewallSubnetId string

@description('Optional static private IP to assign to the firewall in AzureFirewallSubnet (recommended when using UDRs that reference the firewall).')
param firewallPrivateIp string = ''

@description('Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var firewallName = '${firewallBaseName}-${environment}-${suffix}'
var policyName = '${firewallPolicyBaseName}-${environment}-${suffix}'
var pipName = '${firewallPipBaseName}-${environment}-${suffix}'

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: pipName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource policy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: policyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Premium'
    }
    threatIntelMode: 'Alert'

    // Baseline IDPS settings (tune per enterprise requirements).
    intrusionDetection: {
      mode: 'Alert'
    }

    // TLS inspection is intentionally not enabled by default here.
    // Enabling it requires an enterprise CA, certificate management, and clear traffic constraints.
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Premium'
    }
    firewallPolicy: {
      id: policy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: pip.id
          }
          privateIPAddress: (firewallPrivateIp != '') ? firewallPrivateIp : null
        }
      }
    ]
  }
}

resource fwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${firewall.name}'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
      {
        category: 'AZFWThreatIntel'
        enabled: true
      }
      {
        category: 'AZFWIdpsSignature'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output firewallId string = firewall.id
output firewallName string = firewall.name
output firewallPublicIpId string = pip.id
output firewallPolicyId string = policy.id
output firewallPrivateIp string = (firewallPrivateIp != '') ? firewallPrivateIp : firewall.properties.ipConfigurations[0].properties.privateIPAddress
