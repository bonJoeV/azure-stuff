targetScope = 'subscription'

@description('Environment name (e.g., dev).')
param environment string = 'dev'

@description('Azure region for regional resources.')
param location string = 'eastus'

@description('Tenant ID for Key Vault.')
param tenantId string

@description('Public hostname to secure on App Gateway (e.g., app1.example.com).')
param httpsHostName string = 'app1.example.com'

@description('Hub resource group name.')
param hubResourceGroupName string = 'rg-hub-${environment}'

@description('Spoke resource group name.')
param spokeResourceGroupName string = 'rg-spoke-app1-${environment}'

@description('Static private IP for Azure Firewall in AzureFirewallSubnet (must be within firewall subnet).')
param firewallPrivateIp string = '10.0.0.4'

@description('Static private IP for the App Service Private Endpoint (must be within spoke private endpoints subnet).')
param appPrivateEndpointIp string = '10.10.2.10'

@description('Tags applied to all resources.')
param tags object = {
  owner: 'PlatformTeam'
  service: 'ingress'
  environment: environment
}

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

// Reuse the AppGW onboarding example to build hub+spoke, firewall, dns, and a private App Service backend.
module base '../appgw-onboarding/main.bicep' = {
  name: 'base-${environment}'
  params: {
    environment: environment
    location: location
    hubResourceGroupName: hubResourceGroupName
    spokeResourceGroupName: spokeResourceGroupName
    firewallPrivateIp: firewallPrivateIp
    appPrivateEndpointIp: appPrivateEndpointIp
    samplePublicHostName: httpsHostName
  }
}

// Create a Key Vault suitable for AppGW listener certs.
// NOTE: In many environments, AppGW -> Key Vault integration is easiest with publicNetworkAccess Enabled + restrictive ACLs.
module kv '../../modules/security/keyVaultForCerts.bicep' = {
  name: 'kv-${environment}'
  scope: hubRg
  params: {
    environment: environment
    location: location
    keyVaultBaseName: 'kvingress'
    tenantId: tenantId
    publicNetworkAccess: 'Enabled'
    networkDefaultAction: 'Deny'
    networkBypass: 'AzureServices'
    tags: tags
  }
}

// Create a self-signed cert in Key Vault and get the secretId for AppGW.
module cert '../../modules/security/keyVaultSelfSignedCertificate.bicep' = {
  name: 'cert-${environment}'
  scope: hubRg
  params: {
    keyVaultId: kv.outputs.keyVaultId
    certificateName: 'listener'
    subjectName: 'CN=${httpsHostName}'
    validityInMonths: 6
  }
}

// NOTE: This example does not reconfigure the base App Gateway routing rules to HTTPS.
// It demonstrates how to produce a Key Vault secret ID and wire it into an HTTPS listener.
// For production, implement app-specific HTTPS listeners/rules in an onboarding module.

output keyVaultName string = kv.outputs.keyVaultName
output keyVaultSecretId string = cert.outputs.keyVaultSecretId
