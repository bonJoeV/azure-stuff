@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Traffic Manager profile base name (environment + unique suffix are added).')
param profileBaseName string = 'tm-ingress'

@description('Routing method. For primary/secondary use: Priority')
@allowed([
  'Priority'
  'Performance'
  'Weighted'
  'Geographic'
  'Multivalue'
  'Subnet'
])
param routingMethod string = 'Priority'

@description('DNS relative name for the Traffic Manager profile. Must be globally unique within trafficmanager.net.')
param dnsRelativeName string

@description('DNS TTL in seconds.')
param ttl int = 30

@description('Monitor protocol: HTTP | HTTPS | TCP')
@allowed([
  'HTTP'
  'HTTPS'
  'TCP'
])
param monitorProtocol string = 'HTTPS'

@description('Monitor port.')
param monitorPort int = 443

@description('Monitor path for HTTP/HTTPS monitors.')
param monitorPath string = '/'

@description('Primary endpoint target FQDN (e.g., <endpoint>.azurefd.net).')
param primaryExternalFqdn string

@description('Secondary endpoint Azure Public IP resource ID (e.g., App Gateway Public IP).')
param secondaryAzurePublicIpResourceId string

@description('Tags applied to all resources where supported.')
param tags object = {}

var profileName = '${profileBaseName}-${environment}-${uniqueString(resourceGroup().id)}'

resource profile 'Microsoft.Network/trafficManagerProfiles@2022-04-01' = {
  name: profileName
  tags: tags
  properties: {
    profileStatus: 'Enabled'
    trafficRoutingMethod: routingMethod
    dnsConfig: {
      relativeName: dnsRelativeName
      ttl: ttl
    }
    monitorConfig: {
      protocol: monitorProtocol
      port: monitorPort
      path: monitorPath
      intervalInSeconds: 30
      timeoutInSeconds: 10
      toleratedNumberOfFailures: 3
    }
  }
}

resource primary 'Microsoft.Network/trafficManagerProfiles/externalEndpoints@2022-04-01' = {
  name: '${profile.name}/primary-afd'
  properties: {
    target: primaryExternalFqdn
    endpointStatus: 'Enabled'
    priority: 1
  }
}

resource secondary 'Microsoft.Network/trafficManagerProfiles/azureEndpoints@2022-04-01' = {
  name: '${profile.name}/secondary-agw'
  properties: {
    targetResourceId: secondaryAzurePublicIpResourceId
    endpointStatus: 'Enabled'
    priority: 2
  }
}

output trafficManagerProfileId string = profile.id
output trafficManagerDnsName string = '${dnsRelativeName}.trafficmanager.net'
