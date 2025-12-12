@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Azure region for regional resources.')
param location string

@description('Key Vault base name (environment + unique suffix are added).')
param keyVaultBaseName string = 'kv-ingress'

@description('Tenant ID for Key Vault.')
param tenantId string

@description('Enable RBAC authorization for Key Vault (recommended for many enterprises).')
param enableRbacAuthorization bool = false

@description('Public network access for the vault. For App Gateway Key Vault integration, many environments keep this Enabled with restrictive network ACLs.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@description('Network default action when publicNetworkAccess is Enabled.')
@allowed([
  'Allow'
  'Deny'
])
param networkDefaultAction string = 'Deny'

@description('Bypass setting for Key Vault network ACLs.')
@allowed([
  'None'
  'AzureServices'
])
param networkBypass string = 'AzureServices'

@description('Object ID of the admin principal to grant full access (optional).')
param adminObjectId string = ''

@description('Optional object ID of a managed identity to grant secret get/list (e.g., App Gateway identity).')
param secretsReaderObjectId string = ''

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var kvName = toLower(replace('${keyVaultBaseName}-${environment}-${suffix}', '-', ''))

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    enabledForTemplateDeployment: true
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      bypass: networkBypass
      defaultAction: networkDefaultAction
    }
    accessPolicies: enableRbacAuthorization ? [] : concat(
      adminObjectId != '' ? [
        {
          tenantId: tenantId
          objectId: adminObjectId
          permissions: {
            secrets: [
              'Get'
              'List'
              'Set'
              'Delete'
              'Purge'
              'Recover'
            ]
            certificates: [
              'Get'
              'List'
              'Create'
              'Import'
              'Update'
              'Delete'
              'Purge'
              'Recover'
              'ManageContacts'
              'ManageIssuers'
              'GetIssuers'
              'ListIssuers'
              'SetIssuers'
              'DeleteIssuers'
            ]
          }
        }
      ] : [],
      secretsReaderObjectId != '' ? [
        {
          tenantId: tenantId
          objectId: secretsReaderObjectId
          permissions: {
            secrets: [
              'Get'
              'List'
            ]
          }
        }
      ] : []
    )
  }
}

output keyVaultId string = kv.id
output keyVaultName string = kv.name
output keyVaultUri string = kv.properties.vaultUri
