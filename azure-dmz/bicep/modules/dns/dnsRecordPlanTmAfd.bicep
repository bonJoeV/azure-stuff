@description('DNS zone name (e.g., contoso.com).')
param dnsZoneName string

@description('Relative record name for the application (e.g., app).')
param appRecordName string

@description('Traffic Manager DNS name (e.g., <name>.trafficmanager.net).')
param trafficManagerDnsName string

@description('AFD endpoint hostname (e.g., <endpoint>.azurefd.net).')
param frontDoorEndpointHostName string

@description('Optional Traffic Manager TTL in seconds for the app CNAME.')
param ttl int = 30

@description('Optional App Gateway public IP address for a break-glass A record (secondary direct).')
param appGatewayPublicIp string = ''

@description('Optional validation token, if AFD returns one for TXT-based validation in your tenant/SKU. Leave blank if not applicable.')
param frontDoorValidationToken string = ''

var appFqdn = '${appRecordName}.${dnsZoneName}'
var afdVerifyRecordName = 'afdverify.${appRecordName}'
var afdVerifyTarget = 'afdverify.${frontDoorEndpointHostName}'

// Outputs a ready-to-send list of DNS changes for a DNS team.
// Notes:
// - AFD custom domain validation commonly uses the `afdverify` CNAME so you can keep the live `app` CNAME pointed at Traffic Manager.
// - Some configurations also expose a TXT token; if provided, we output a suggested _dnsauth TXT record.

output dnsRecords array = concat(
  [
    {
      type: 'CNAME'
      name: appRecordName
      fqdn: appFqdn
      ttl: ttl
      value: trafficManagerDnsName
      purpose: 'Public entrypoint: app hostname points to Traffic Manager (Priority failover).'
    }
    {
      type: 'CNAME'
      name: afdVerifyRecordName
      fqdn: '${afdVerifyRecordName}.${dnsZoneName}'
      ttl: ttl
      value: afdVerifyTarget
      purpose: 'AFD domain validation without changing the live app hostname CNAME.'
    }
  ],
  (frontDoorValidationToken != '') ? [
    {
      type: 'TXT'
      name: '_dnsauth.${appRecordName}'
      fqdn: '_dnsauth.${appRecordName}.${dnsZoneName}'
      ttl: ttl
      value: frontDoorValidationToken
      purpose: 'AFD TXT-based domain validation token (only if required/returned by AFD in your environment).'
    }
  ] : [],
  (appGatewayPublicIp != '') ? [
    {
      type: 'A'
      name: '${appRecordName}-agw'
      fqdn: '${appRecordName}-agw.${dnsZoneName}'
      ttl: ttl
      value: appGatewayPublicIp
      purpose: 'Optional break-glass direct-to-AppGW record (bypasses Traffic Manager).'
    }
  ] : []
)
