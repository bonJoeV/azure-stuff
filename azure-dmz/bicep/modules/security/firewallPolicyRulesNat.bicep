@description('Firewall Policy resource ID.')
param firewallPolicyId string

@description('Rule collection group name.')
param ruleCollectionGroupName string = 'rcg-ingress'

@description('Priority for the rule collection group (100-65000).')
param priority int = 200

@description('Array of NAT rules to add.')
param natRules array

resource rcg 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2023-11-01' = {
  name: '${last(split(firewallPolicyId, '/'))}/${ruleCollectionGroupName}'
  properties: {
    priority: priority
    ruleCollections: [
      {
        name: 'nat-collection'
        priority: 200
        ruleCollectionType: 'FirewallPolicyNatRuleCollection'
        action: {
          type: 'Dnat'
        }
        rules: natRules
      }
    ]
  }
}

output ruleCollectionGroupId string = rcg.id
