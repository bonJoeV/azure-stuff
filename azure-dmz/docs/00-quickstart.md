# Quickstart (Front Door primary + App Gateway failover via Traffic Manager)

This quickstart is aimed at people new to the repo and gives a “happy path” deployment using the combined example.

## What you deploy
- AFD (Front Door Std/Prem) path: Internet → AFD (+WAF) → Firewall public IP (DNAT) → Private Endpoint → App Service
- AppGW path: Internet → App Gateway WAF v2 → (UDR forced) Firewall → Private Endpoint → App Service
- Traffic Manager Priority profile out front: **primary = AFD**, **secondary = AppGW**

## Prereqs
- Azure subscription where you can create resource groups and deploy at subscription scope
- `az` CLI authenticated (`az login`) and set to the right subscription (`az account set --subscription <id>`)
- Address spaces in the examples do not overlap with existing VNets in your subscription

## Deploy (combined example)
1. Pick a globally-unique Traffic Manager label.
   - Edit [bicep/examples/tm-afd-primary-agw-failover/parameters.json](../bicep/examples/tm-afd-primary-agw-failover/parameters.json)
   - Set `tmRelativeName` to something unique, e.g. `ingress-dev-<yourorg>-<random>`

2. Deploy:

```powershell
az deployment sub create `
  --location eastus `
  --template-file bicep/examples/tm-afd-primary-agw-failover/main.bicep `
  --parameters @bicep/examples/tm-afd-primary-agw-failover/parameters.json
```

## Validate (basic)
- Confirm Traffic Manager DNS name was output.
- Confirm AFD endpoint hostname was output.
- Confirm AppGW public IP was output.

### Validate Traffic Manager resolution
From a client machine:
- `nslookup <tmRelativeName>.trafficmanager.net`

You should see it resolve to the **primary** target (AFD) when healthy.

### Validate failover behavior (expected)
- Traffic Manager failover is **DNS-based**. Even with low TTL, clients may cache results.
- For a quick test, temporarily disable the primary endpoint in the Traffic Manager profile and re-query DNS.

## Next steps for “real” use
- Add custom domain(s) and certificates to both AFD and AppGW (or define a planned break-glass hostname).
- Align WAF baselines/exclusions between AFD WAF and AppGW WAF.
- Move the example into your landing zone pipelines (CI/CD) and parameterize address plans and naming.

## DNS team handoff (record plan outputs)
If DNS is managed by a separate team, deploy the combined example and hand them the `dnsRecordsToRequest` output from:
- [bicep/examples/tm-afd-primary-agw-failover/main.bicep](../bicep/examples/tm-afd-primary-agw-failover/main.bicep)

It outputs the minimum recommended records:
- `app.<zone>` CNAME → `<tm>.trafficmanager.net`
- `afdverify.app.<zone>` CNAME → `afdverify.<endpoint>.azurefd.net` (AFD validation)

If a TXT validation token is returned by AFD in your environment, it will be included as well.

Recommended: review production decisions before rollout: [docs/05-production-decisions.md](05-production-decisions.md)

See the ops checklist: [docs/04-tm-afd-primary-agw-failover-checklist.md](04-tm-afd-primary-agw-failover-checklist.md)
