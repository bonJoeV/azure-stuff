# 3) Governance Policy Set for DMZ Enforcement

See the policy implementation in:
- Initiative: [policy/initiative/dmz-ingress-initiative.json](../policy/initiative/dmz-ingress-initiative.json)
- Definitions: [policy/definitions](../policy/definitions)
- Mapping: [policy/policy-mapping.md](../policy/policy-mapping.md)

## How to scope
- Define the initiative at the **management group** (recommended).
- Assign the initiative to the **Landing Zones management group**.
- Exclude platform subscriptions at assignment time using `notScopes` (or use Policy Exemptions).

## Why some controls are Audit
- “Require Private Endpoints everywhere” is not universally enforceable with a single Deny across all Azure services.
- A pragmatic enterprise approach is:
  - Deny clear anti-patterns (public IPs, open NSG inbound)
  - Use Audit + onboarding tags/registrations for broad coverage
  - Add service-specific Deny policies where the resource provider exposes reliable properties
