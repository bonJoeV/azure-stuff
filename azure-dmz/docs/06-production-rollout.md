# Production rollout guide

This guide describes how to take the repo from examples to an enterprise rollout.

## 1) Establish management group and subscription boundaries
- Platform MG: Connectivity + Management subscriptions
- Landing Zones MG: workload subscriptions

## 2) Deploy the Connectivity / DMZ landing zone
- Start with [bicep/main.bicep](../bicep/main.bicep) into the Connectivity subscription
- Parameterize:
  - hub address space/subnets
  - naming/tagging
  - ingress type (Front Door vs App Gateway)

## 3) Decide and implement DNS ownership
Choose one:
- Azure DNS public zones (Azure-native)
- External DNS (Infoblox/Route53/other)

If Azure DNS:
- Use [bicep/modules/dns/publicDnsRecords.bicep](../bicep/modules/dns/publicDnsRecords.bicep) to create:
  - CNAME for Traffic Manager (`app` → `<tm>.trafficmanager.net`)
  - AFD validation records (as required) and CNAME to AFD endpoint

## 4) Certificates
- AFD managed TLS is easiest (requires DNS validation + CNAME)
- AppGW requires a PFX in Key Vault

Implementation options:
- Production: import a CA-issued cert into Key Vault and rotate via defined process
- Dev/test: create a self-signed cert in Key Vault via [bicep/modules/security/keyVaultSelfSignedCertificate.bicep](../bicep/modules/security/keyVaultSelfSignedCertificate.bicep)

Key Vault resiliency guidance:
- [docs/07-key-vault-resiliency.md](07-key-vault-resiliency.md)

## 5) Roll out the failover pattern
- Deploy the combined example first to validate behavior:
  - [docs/00-quickstart.md](00-quickstart.md)
- Harden per:
  - [docs/04-tm-afd-primary-agw-failover-checklist.md](04-tm-afd-primary-agw-failover-checklist.md)
  - [docs/05-production-decisions.md](05-production-decisions.md)

## 6) Governance
- Define and assign the initiative at MG scope:
  - [policy/initiative/dmz-ingress-initiative.json](../policy/initiative/dmz-ingress-initiative.json)
- Add service-specific denies as you standardize services.

## 7) CI/CD
- CI validates Bicep compilation on every PR:
  - [.github/workflows/ci.yml](../.github/workflows/ci.yml)
- Recommended: add deployment pipelines per environment with approvals.

## 8) DR drills
- Run failover drills regularly and measure time-to-recover.
- Update WAF baselines/exclusions from drill learnings.
