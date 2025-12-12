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

@description('Traffic Manager DNS relative name (must be globally unique).')
param tmRelativeName string = 'ingress-${environment}-${uniqueString(subscription().id)}'

@description('Public DNS zone name (Azure DNS or external) used for the application hostname, e.g. contoso.com.')
param dnsZoneName string = 'example.com'

@description('Relative DNS record name for the application, e.g. app -> app.contoso.com.')
param appRecordName string = 'app'

@description('Static private IP for Azure Firewall in AzureFirewallSubnet (must be within firewall subnet).')
param firewallPrivateIp string = '10.0.0.4'

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

// Deploy the AppGW path (secondary endpoint) and a private backend.
module appgwExample '../appgw-onboarding/main.bicep' = {
  name: 'example-appgw-${environment}'
  params: {
    environment: environment
    location: location
    hubResourceGroupName: hubResourceGroupName
    spokeResourceGroupName: spokeResourceGroupName
    firewallPrivateIp: firewallPrivateIp
    samplePublicHostName: 'app1.example.com'
    appPrivateEndpointIp: appPrivateEndpointIp
  }
}

// Deploy the AFD + Firewall DNAT HTTPS path (primary endpoint).
module afdExample '../afd-firewall-dnat-https-onboarding/main.bicep' = {
  name: 'example-afd-${environment}'
  params: {
    environment: environment
    location: location
    hubResourceGroupName: hubResourceGroupName
    spokeResourceGroupName: spokeResourceGroupName
    firewallPrivateIp: firewallPrivateIp
    appPrivateEndpointIp: appPrivateEndpointIp
    wafMode: 'Detection'
    // Optional: create an AFD custom domain so we can output validation details for the DNS team.
    // This does NOT create DNS records; see dnsPlan outputs.
    customDomainHostName: '${appRecordName}.${dnsZoneName}'
    customDomainCertificateType: 'ManagedCertificate'
  }
}

// Traffic Manager profile out front.
// NOTE: Traffic Manager failover is DNS-based; plan for TTL and client DNS caching.
module tm '../../modules/ingress/trafficManagerFailover.bicep' = {
  name: 'tm-${environment}'
  scope: hubRg
  params: {
    environment: environment
    dnsRelativeName: tmRelativeName
    primaryExternalFqdn: afdExample.outputs.frontDoorEndpointHostName
    secondaryAzurePublicIpResourceId: appgwExample.outputs.appGatewayPublicIpId
    monitorProtocol: 'HTTPS'
    monitorPort: 443
    monitorPath: '/'
    tags: tags
  }
}

module dnsPlan '../../modules/dns/dnsRecordPlanTmAfd.bicep' = {
  name: 'dns-plan-${environment}'
  scope: hubRg
  params: {
    dnsZoneName: dnsZoneName
    appRecordName: appRecordName
    trafficManagerDnsName: tm.outputs.trafficManagerDnsName
    frontDoorEndpointHostName: afdExample.outputs.frontDoorEndpointHostName
    frontDoorValidationToken: afdExample.outputs.customDomainValidationToken
    appGatewayPublicIp: appgwExample.outputs.appGatewayPublicIp
    ttl: 30
  }
}

output trafficManagerDnsName string = tm.outputs.trafficManagerDnsName
output primaryAfdEndpointHostName string = afdExample.outputs.frontDoorEndpointHostName
output secondaryAppGwPublicIp string = appgwExample.outputs.appGatewayPublicIp
output dnsRecordsToRequest array = dnsPlan.outputs.dnsRecords
