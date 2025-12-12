# Azure Policy – DMZ Enforcement

This folder contains an initiative and sample assignment used to enforce centralized inbound access patterns.

## Contents
- Initiative definition: [initiative/dmz-ingress-initiative.json](initiative/dmz-ingress-initiative.json)
- Custom policy definitions: [definitions](definitions)
- Sample management group assignment with platform exclusions: [assignments/assign-initiative-mg.json](assignments/assign-initiative-mg.json)
- Mapping table: [policy-mapping.md](policy-mapping.md)

## Notes
- Exempting platform subscriptions is done at **assignment time** via `notScopes` (or exemptions), not inside the initiative itself.
- Some controls are expressed as **Audit** when a reliable **Deny** is impractical across all resource types.

## Hardening coverage
In addition to the baseline DMZ guardrails (no Public IPs, no open inbound NSG rules, diagnostics), the initiative includes a practical “private-only PaaS” hardening pack for common services:
- Key Vault, Storage, App Service, Azure SQL, Cosmos DB, Container Registry, API Management

Most of these policies parameterize the `effect` so you can start in `Audit` and move to `Deny` once onboarding is complete.
