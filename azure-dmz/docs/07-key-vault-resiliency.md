# Key Vault resiliency and “what if Key Vault fails?”

You’ve chosen **Public CA certificates stored in Azure Key Vault** for both:
- Azure Front Door (AFD) customer-managed TLS
- Application Gateway (AppGW) TLS listener certificates

This raises a common enterprise question: what happens if Key Vault is degraded or unavailable?

## What actually breaks during a Key Vault outage

### 1) Existing traffic (steady state)
In most designs, **existing certificates are already loaded/cached** by the consuming service.
- **App Gateway** typically continues serving the currently loaded certificate during a Key Vault outage.
- **AFD** typically continues serving the currently loaded certificate during a Key Vault outage.

What you lose is **the ability to refresh/rotate** certificates while Key Vault is unavailable.

> Treat this as a resilience pattern for *operations*, not necessarily for *steady-state availability*.

### 2) Certificate rotation / renewal
If Key Vault is down when a rotation is due:
- Automatic or scheduled certificate refresh may fail.
- You risk reaching the certificate expiry window without successfully updating the edge/gateway.

### 3) Scale events / rehydration
Depending on service behavior, scaling or rehydration can increase reliance on Key Vault.
- If a new instance needs to fetch the cert and Key Vault is unreachable, you may see delayed scale-out or degraded recovery.

Because exact behavior can vary by SKU and platform changes, treat this as a risk to test in a drill.

## Mitigations (recommended)

### A) Reduce blast radius with vault design
- **Use two vaults** (primary + secondary) in paired regions.
- Use **soft delete + purge protection**.
- Use **backups/exports** for certificates and secrets (process + automation).
- Use **private endpoints** where possible for data-plane protection, but note that some integrations are easier with controlled public access.

### B) Break-glass certificate plan
Have a documented emergency option that does not depend on the primary Key Vault being healthy at that moment.

Patterns:
- **Dual certificate objects** (primary + secondary) pre-provisioned:
  - AppGW: keep two `sslCertificates` and pre-create an alternate listener (or make switching one change away).
  - AFD: pre-create a second `Microsoft.Cdn/profiles/secrets` referencing the secondary vault and keep a runbook to swap.

### C) Monitoring and alerting
Alert on signals that correlate to “rotation risk,” not just uptime:
- Key Vault availability / throttling
- AppGW/AFD certificate refresh errors
- Certificate expiry approaching (e.g., < 30 days)

### D) Operational guardrails
- Rotate early (e.g., **30–60 days** before expiry).
- Use short, rehearsed runbooks for:
  - swapping to secondary vault secret
  - redeploying listeners/routes

## Strategic option: remove Key Vault from the edge path (if acceptable)
If policy allows, **AFD managed certificates** reduce reliance on Key Vault for the edge tier.
You can still use Key Vault for AppGW and backend certs.

## Recommended drill
At least twice per year:
- Simulate Key Vault data-plane unavailability.
- Validate:
  - existing traffic continues
  - a forced cert refresh/rotation behaves as expected
  - break-glass swap procedures work
