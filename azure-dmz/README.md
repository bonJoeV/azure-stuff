# Enterprise Azure DMZ / Ingress as a Service

This repo provides a reference implementation for a centralized Azure DMZ / inbound ingress model operated by a central platform team.

## Contents
- Architecture: [docs/01-architecture.md](docs/01-architecture.md)
- Quickstart: [docs/00-quickstart.md](docs/00-quickstart.md)
- Operating model: [docs/02-operating-model.md](docs/02-operating-model.md)
- Ops checklist (TM + AFD primary, AppGW secondary): [docs/04-tm-afd-primary-agw-failover-checklist.md](docs/04-tm-afd-primary-agw-failover-checklist.md)
- Production decisions: [docs/05-production-decisions.md](docs/05-production-decisions.md)
- Production rollout: [docs/06-production-rollout.md](docs/06-production-rollout.md)
- Key Vault resiliency: [docs/07-key-vault-resiliency.md](docs/07-key-vault-resiliency.md)
- Bicep landing zone: [bicep/README.md](bicep/README.md)
- Azure Policy initiative: [policy/README.md](policy/README.md)

## High-level intent
- Centralize north-south ingress and enforcement (WAF + Firewall + DDoS)
- Workloads live in spoke subscriptions and are reachable only via Private Endpoints
- Logs flow to Log Analytics and can be connected to Microsoft Sentinel

> Note: Some combinations (especially Azure Front Door → Azure Firewall) have practical constraints. The architecture doc calls out supported patterns and trade-offs.
