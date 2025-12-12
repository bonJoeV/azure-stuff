@description('Resource group name containing the Azure DNS zone.')
param dnsZoneResourceGroupName string

@description('DNS zone name (e.g., contoso.com).')
param dnsZoneName string

@description('Records to create. Each item: { type: "CNAME"|"TXT"|"A", name: "relative", ttl: 30, value: "..." }')
param records array

resource dnsRg 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: dnsZoneResourceGroupName
}

resource zone 'Microsoft.Network/dnsZones@2018-05-01' existing = {
  name: dnsZoneName
  scope: dnsRg
}

resource cnameRecords 'Microsoft.Network/dnsZones/CNAME@2018-05-01' = [for r in records: if (toUpper(r.type) == 'CNAME') {
  name: '${zone.name}/${r.name}'
  properties: {
    TTL: r.ttl
    CNAMERecord: {
      cname: r.value
    }
  }
}]

resource txtRecords 'Microsoft.Network/dnsZones/TXT@2018-05-01' = [for r in records: if (toUpper(r.type) == 'TXT') {
  name: '${zone.name}/${r.name}'
  properties: {
    TTL: r.ttl
    TXTRecords: [
      {
        value: [
          r.value
        ]
      }
    ]
  }
}]

resource aRecords 'Microsoft.Network/dnsZones/A@2018-05-01' = [for r in records: if (toUpper(r.type) == 'A') {
  name: '${zone.name}/${r.name}'
  properties: {
    TTL: r.ttl
    ARecords: [
      {
        ipv4Address: r.value
      }
    ]
  }
}]

output zoneId string = zone.id
