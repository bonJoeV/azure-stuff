@description('AFD profile resource ID (Microsoft.Cdn/profiles).')
param frontDoorProfileId string

@description('Name of the secret resource under the AFD profile.')
param secretName string

@description('Key Vault secret ID for a PFX certificate (https://<kv>.vault.azure.net/secrets/<name>/<version>).')
param keyVaultSecretId string

var profileName = last(split(frontDoorProfileId, '/'))

// For AFD customer-managed certificates, you create a "secret" resource pointing at a Key Vault secret.
resource secret 'Microsoft.Cdn/profiles/secrets@2024-02-01' = {
  name: '${profileName}/${secretName}'
  properties: {
    parameters: {
      type: 'AzureKeyVaultCertificate'
      secretSource: {
        id: keyVaultSecretId
      }
      useLatestVersion: true
    }
  }
}

output secretId string = secret.id
