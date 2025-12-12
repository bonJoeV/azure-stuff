@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Log Analytics workspace SKU.')
param sku string = 'PerGB2018'

@description('Tags applied to all resources where supported.')
param tags object = {}

var workspaceName = 'law-${environment}-${uniqueString(resourceGroup().id)}'

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
