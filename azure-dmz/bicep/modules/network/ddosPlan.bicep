@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Base name for the DDoS plan (environment + unique suffix are added).')
param ddosPlanBaseName string

@description('Tags applied to all resources where supported.')
param tags object = {}

var ddosPlanName = '${ddosPlanBaseName}-${environment}-${uniqueString(resourceGroup().id)}'

resource ddosPlan 'Microsoft.Network/ddosProtectionPlans@2023-11-01' = {
  name: ddosPlanName
  location: location
  tags: tags
}

output ddosPlanId string = ddosPlan.id
