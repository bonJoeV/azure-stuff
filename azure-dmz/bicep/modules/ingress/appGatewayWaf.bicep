@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Application Gateway base name (environment + unique suffix are added).')
param appGatewayBaseName string

@description('Public IP base name for Application Gateway (environment + unique suffix are added).')
param publicIpBaseName string

@description('Resource ID of the Application Gateway subnet in the hub VNet.')
param appGatewaySubnetId string

@description('Log Analytics workspace resource ID for diagnostics.')
param logAnalyticsWorkspaceId string

@description('Enable a minimal sample HTTP listener + routing rule for onboarding examples.')
param enableSampleOnboarding bool = false

@description('Sample public hostname (used as host header match). Only used when enableSampleOnboarding=true.')
param sampleListenerHostName string = ''

@description('Sample backend FQDN (resolved via Private DNS to a Private Endpoint). Only used when enableSampleOnboarding=true.')
param sampleBackendFqdn string = ''

@description('Enable an HTTPS listener using a certificate stored in Key Vault (AppGW must have identity access).')
param enableHttpsListener bool = false

@description('Key Vault secret ID containing a PFX cert for AppGW HTTPS listener (e.g., https://<kv>.vault.azure.net/secrets/<name>/<version>).')
param keyVaultSecretId string = ''

@description('Public hostname for HTTPS listener SNI/Host header match. Only used when enableHttpsListener=true.')
param httpsListenerHostName string = ''

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var pipName = '${publicIpBaseName}-${environment}-${suffix}'
var appGwName = '${appGatewayBaseName}-${environment}-${suffix}'
var wafPolicyName = 'waf-${appGwName}'

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

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: wafPolicyName
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

resource appGw 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: appGwName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'gwip'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'feip'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
    frontendPorts: enableSampleOnboarding ? concat(
      [
        {
          name: 'port-http'
          properties: {
            port: 80
          }
        }
      ],
      enableHttpsListener ? [
        {
          name: 'port-https'
          properties: {
            port: 443
          }
        }
      ] : []
    ) : [
      {
        name: 'port-https'
        properties: {
          port: 443
        }
      }
    ]

    identity: enableHttpsListener ? {
      type: 'SystemAssigned'
    } : null

    sslCertificates: enableHttpsListener ? [
      {
        name: 'kv-cert'
        properties: {
          keyVaultSecretId: keyVaultSecretId
        }
      }
    ] : null

    // Listener/routing is intentionally minimal; optionally enabled for onboarding examples.
    backendAddressPools: enableSampleOnboarding ? [
      {
        name: 'be-sample'
        properties: {
          backendAddresses: [
            {
              fqdn: sampleBackendFqdn
            }
          ]
        }
      }
    ] : []

    backendHttpSettingsCollection: enableSampleOnboarding ? [
      {
        name: 'behttp-sample'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
          requestTimeout: 30
        }
      }
    ] : []

    httpListeners: enableSampleOnboarding ? [
      {
        name: 'listener-sample-http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw.name, 'feip')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw.name, 'port-http')
          }
          protocol: 'Http'
          hostName: sampleListenerHostName
          requireServerNameIndication: false
        }
      }
    ] : []

    // Optional HTTPS listener for production use (requires Key Vault secret and identity permissions)
    // Note: request routing rules for HTTPS are still workload-specific; this provides a listener scaffold.
    // If you need end-to-end HTTPS routing rules, add them in an onboarding module per app.
    

    requestRoutingRules: enableSampleOnboarding ? [
      {
        name: 'rule-sample'
        properties: {
          ruleType: 'Basic'
          priority: 100
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGw.name, 'listener-sample-http')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGw.name, 'be-sample')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGw.name, 'behttp-sample')
          }
        }
      }
    ] : []
    // Listener/routing is intentionally minimal; app onboarding adds listeners, rules, backend pools.
    httpListeners: []
    backendAddressPools: []
    backendHttpSettingsCollection: []
    requestRoutingRules: []

    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }

    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}

resource httpsListener 'Microsoft.Network/applicationGateways/httpListeners@2023-11-01' = if (enableHttpsListener) {
  name: '${appGw.name}/listener-https'
  properties: {
    frontendIPConfiguration: {
      id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGw.name, 'feip')
    }
    frontendPort: {
      id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGw.name, 'port-https')
    }
    protocol: 'Https'
    hostName: httpsListenerHostName
    sslCertificate: {
      id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGw.name, 'kv-cert')
    }
    requireServerNameIndication: true
  }
  dependsOn: [
    appGw
  ]
}

output appGatewayIdentityPrincipalId string = enableHttpsListener ? appGw.identity.principalId : ''

resource appGwDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${appGw.name}'
  scope: appGw
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
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

output appGatewayId string = appGw.id
output appGatewayName string = appGw.name
output appGatewayPublicIpId string = pip.id
