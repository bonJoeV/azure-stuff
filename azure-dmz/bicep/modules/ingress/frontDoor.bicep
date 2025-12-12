@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Location parameter is required for deployments; Front Door is a global service.')
param location string

@description('Front Door profile base name (environment + unique suffix are added).')
param profileBaseName string

@description('Log Analytics workspace resource ID for diagnostics (where supported).')
param logAnalyticsWorkspaceId string

@description('Enable a minimal sample route/origin for onboarding examples.')
param enableSampleOnboarding bool = false

@description('Sample origin host name (e.g., Firewall public IP). Only used when enableSampleOnboarding=true.')
param sampleOriginHostName string = ''

@description('Sample origin HTTP port.')
param sampleOriginHttpPort int = 80

@description('Sample origin HTTPS port.')
param sampleOriginHttpsPort int = 443

@description('Sample forwarding protocol: HttpOnly | HttpsOnly | MatchRequest.')
@allowed([
  'HttpOnly'
  'HttpsOnly'
  'MatchRequest'
])
param sampleForwardingProtocol string = 'HttpOnly'

@description('Sample custom domain host name is not configured by default. This is only used as a matching host header if provided.')
param sampleRouteHostName string = ''

@description('Optional custom domain host name to create for AFD (e.g., app.contoso.com). This module does not create DNS records.')
param customDomainHostName string = ''

@description('TLS cert type for custom domain. CustomerCertificate uses an AFD "secret" resource that references a Key Vault secret containing a PFX.')
@allowed([
  'ManagedCertificate'
  'CustomerCertificate'
])
param customDomainCertificateType string = 'ManagedCertificate'

@description('AFD secret resource ID (Microsoft.Cdn/profiles/secrets) to use when certificateType=CustomerCertificate.')
param customDomainAfdSecretId string = ''

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var profileName = '${profileBaseName}-${environment}-${suffix}'

// Azure Front Door Standard/Premium uses Microsoft.Cdn (AFD v2).
resource profile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: profileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  name: '${profile.name}/endpoint-${environment}'
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = if (enableSampleOnboarding) {
  name: '${profile.name}/og-sample'
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    healthProbeSettings: {
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: (sampleForwardingProtocol == 'HttpsOnly') ? 'Https' : 'Http'
      probeIntervalInSeconds: 60
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = if (enableSampleOnboarding) {
  name: '${profile.name}/og-sample/origin-sample'
  properties: {
    hostName: sampleOriginHostName
    httpPort: sampleOriginHttpPort
    httpsPort: sampleOriginHttpsPort
    originHostHeader: (sampleRouteHostName != '') ? sampleRouteHostName : sampleOriginHostName
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = if (enableSampleOnboarding) {
  name: '${profile.name}/endpoint-${environment}/route-sample'
  properties: {
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: sampleForwardingProtocol
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2024-02-01' = if (customDomainHostName != '') {
  name: '${profile.name}/cd-${uniqueString(customDomainHostName)}'
  properties: {
    hostName: customDomainHostName
    tlsSettings: {
      certificateType: customDomainCertificateType
      minimumTlsVersion: 'TLS12'
      secret: (customDomainCertificateType == 'CustomerCertificate') ? {
        id: customDomainAfdSecretId
      } : null
    }
  }
}

var customDomainRef = (customDomainHostName != '') ? reference(customDomain.id, '2024-02-01') : null
var customDomainValidationToken = (customDomainHostName != '' && contains(customDomainRef.properties, 'validationProperties') && contains(customDomainRef.properties.validationProperties, 'validationToken'))
  ? string(customDomainRef.properties.validationProperties.validationToken)
  : ''

// Note: Attaching the custom domain to routes is app-specific.
// For samples we keep route association minimal to avoid requiring DNS validation steps.

// Origin groups/routes/custom domains/WAF are app-onboarding concerns and vary per workload.
// This module provides the shared profile + endpoint scaffold.

output frontDoorProfileId string = profile.id
output frontDoorProfileName string = profile.name
output frontDoorEndpointId string = endpoint.id
output frontDoorEndpointHostName string = endpoint.properties.hostName
output sampleRouteId string = enableSampleOnboarding ? route.id : ''
output customDomainId string = (customDomainHostName != '') ? customDomain.id : ''
output customDomainName string = (customDomainHostName != '') ? customDomain.name : ''
output customDomainHostName string = customDomainHostName
output customDomainValidationToken string = customDomainValidationToken
