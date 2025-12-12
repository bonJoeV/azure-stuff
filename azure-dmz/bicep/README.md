# Bicep – DMZ / Connectivity Landing Zone

This folder contains a modular Bicep template to deploy a hub connectivity/DMZ landing zone.

## What it deploys
- Hub VNet with subnets for:
  - Azure Firewall
  - Application Gateway
  - Shared services
- Azure Firewall Premium + Firewall Policy (baseline)
- DDoS Network Protection plan and hub VNet association
- Log Analytics workspace
- Private DNS zones for Private Endpoints
- Ingress option:
  - Azure Front Door Standard/Premium (basic scaffold)
  - OR Application Gateway WAF v2

## Deploy
- `main.bicep` is **subscription-scope** and creates a resource group for the hub.
- Example parameters file: [parameters/dev.parameters.json](parameters/dev.parameters.json)

Example (PowerShell):

```powershell
az deployment sub create `
  --location eastus `
  --template-file bicep/main.bicep `
  --parameters @bicep/parameters/dev.parameters.json
```

> If you use TLS inspection on Azure Firewall Premium, plan for enterprise CA, certificate distribution, and supported traffic patterns.

## Examples

- End-to-end App Gateway onboarding (Internet → AppGW → Firewall → Private Endpoint → App Service):
  - Template: `bicep/examples/appgw-onboarding/main.bicep`
  - Params: `bicep/examples/appgw-onboarding/parameters.json`

- End-to-end Front Door + Firewall DNAT onboarding (Internet → Front Door → Firewall public IP (DNAT) → Private Endpoint → App Service):
  - Template: `bicep/examples/afd-firewall-dnat-onboarding/main.bicep`
  - Params: `bicep/examples/afd-firewall-dnat-onboarding/parameters.json`

- End-to-end Front Door + Firewall DNAT (HTTPS) onboarding (Internet → Front Door → Firewall public IP:443 (DNAT) → Private Endpoint:443 → App Service):
  - Template: `bicep/examples/afd-firewall-dnat-https-onboarding/main.bicep`
  - Params (Detection): `bicep/examples/afd-firewall-dnat-https-onboarding/parameters.detection.json`
  - Params (Prevention): `bicep/examples/afd-firewall-dnat-https-onboarding/parameters.prevention.json`

- Traffic Manager failover (DNS) with Front Door as primary and App Gateway as secondary:
  - Template: `bicep/examples/tm-afd-primary-agw-failover/main.bicep`
  - Params: `bicep/examples/tm-afd-primary-agw-failover/parameters.json`
  - Note: update `tmRelativeName` to a globally-unique value.
  - Output: `dnsRecordsToRequest` can be handed to a DNS team.

Example (PowerShell):

```powershell
az deployment sub create `
  --location eastus `
  --template-file bicep/examples/appgw-onboarding/main.bicep `
  --parameters @bicep/examples/appgw-onboarding/parameters.json
```
