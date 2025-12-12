@description('Key Vault resource ID.')
param keyVaultId string

@description('Certificate name inside Key Vault.')
param certificateName string = 'appgw-listener'

@description('Subject name for the self-signed certificate, e.g. CN=app.contoso.com')
param subjectName string

@description('Validity in months.')
param validityInMonths int = 6

@description('Key size.')
@allowed([
  2048
  4096
])
param keySize int = 2048

// Creates a self-signed certificate inside Key Vault.
// Key Vault will also create a backing secret version containing the PFX.
resource cert 'Microsoft.KeyVault/vaults/certificates@2023-07-01' = {
  name: '${last(split(keyVaultId, '/'))}/${certificateName}'
  properties: {
    certificatePolicy: {
      issuerParameters: {
        name: 'Self'
      }
      keyProperties: {
        exportable: true
        keySize: keySize
        keyType: 'RSA'
        reuseKey: false
      }
      lifetimeActions: [
        {
          trigger: {
            lifetimePercentage: 80
          }
          action: {
            actionType: 'AutoRenew'
          }
        }
      ]
      secretProperties: {
        contentType: 'application/x-pkcs12'
      }
      x509CertificateProperties: {
        subject: subjectName
        validityInMonths: validityInMonths
        subjectAlternativeNames: {
          dnsNames: [
            replace(subjectName, 'CN=', '')
          ]
        }
      }
    }
  }
}

output certificateId string = cert.id
// App Gateway expects the Key Vault secret ID (not certificate ID). The secret lives under /secrets/<certName>/<version>.
// We surface the secretId returned by the certificate resource.
output keyVaultSecretId string = cert.properties.secretId
