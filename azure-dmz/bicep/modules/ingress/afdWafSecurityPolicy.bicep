@description('Azure Front Door profile resource ID (Microsoft.Cdn/profiles).')
param frontDoorProfileId string

@description('AFD endpoint resource ID (Microsoft.Cdn/profiles/afdEndpoints) to associate WAF to.')
param afdEndpointId string

@description('AFD WAF policy resource ID (Microsoft.Network/frontDoorWebApplicationFirewallPolicies).')
param wafPolicyId string

@description('Security policy name (child of the AFD profile).')
param securityPolicyName string = 'sp-waf'

@description('Patterns to match for the WAF association.')
param patternsToMatch array = [
  '/*'
]

var profileName = last(split(frontDoorProfileId, '/'))

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-02-01' = {
  name: '${profileName}/${securityPolicyName}'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicyId
      }
      associations: [
        {
          domains: [
            {
              id: afdEndpointId
            }
          ]
          patternsToMatch: patternsToMatch
        }
      ]
    }
  }
}

output securityPolicyId string = securityPolicy.id
