@description('Deployment environment name (e.g., dev, test, prod).')
param environment string

@description('Location parameter is required for deployments; AFD WAF policy is a global resource.')
param location string

@description('Base name for the WAF policy (environment + unique suffix are added).')
param policyBaseName string = 'waf-afd'

@description('WAF mode: Detection | Prevention')
@allowed([
  'Detection'
  'Prevention'
])
param mode string = 'Detection'

@description('Tags applied to all resources where supported.')
param tags object = {}

var suffix = uniqueString(resourceGroup().id)
var policyName = '${policyBaseName}-${environment}-${suffix}'

// AFD WAF policy for Front Door Standard/Premium
resource waf 'Microsoft.Network/frontDoorWebApplicationFirewallPolicies@2022-05-01' = {
  name: policyName
  location: 'global'
  tags: tags
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: mode
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'Microsoft_DefaultRuleSet'
          ruleSetVersion: '2.1'
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: '1.0'
        }
      ]
    }
  }
}

output wafPolicyId string = waf.id
output wafPolicyName string = waf.name
