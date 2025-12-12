# Production decisions (recommended defaults)

This repo includes runnable examples. Before using the patterns in production, decide and document the items below so application teams and SecOps have a single, repeatable standard.

## 1) Primary ingress and failover model

**Chosen by you:** Azure Front Door (primary) + Application Gateway (failover) controlled by Traffic Manager.

Decide:
- Which failures you are mitigating (AFD control plane vs edge/data plane vs origin dependency failures)
- Whether DNS-based failover timing is acceptable for your RTO

Recommended default:
- Keep this as a deliberate “break-glass” capability; use Front Door multi-origin/multi-region failover for most application DR scenarios.

## 2) DNS and failover behavior

Decide:
- Traffic Manager `ttl` (and how you will communicate DNS caching caveats)
- Whether you will publish the same hostname on both ingress paths or use a break-glass hostname

Recommended default:
- TTL 30 seconds
- Same hostname on both, if you can meet certificate and routing requirements

## 3) Certificates and ownership

Decide:
- Certificate source: managed certificate vs Key Vault
- Who owns issuance, renewal, and emergency rotation

Recommended default:
- Central certificate policy with Key Vault integration and a documented rotation window (e.g., rotate 30–60 days before expiry)

Also decide:
- Key Vault resiliency plan (primary/secondary vaults, break-glass swap)

See: [docs/07-key-vault-resiliency.md](07-key-vault-resiliency.md)

## 4) WAF baseline and tuning process

Decide:
- AFD WAF mode defaults per environment (Detection in lower, Prevention in production)
- How you track exceptions (expiry, justification, approvals)

Recommended default:
- New apps start in Detection for a short stabilization window
- Move to Prevention with a measured false-positive threshold and documented exceptions

## 5) Firewall policy scope

Decide:
- What must traverse Azure Firewall (all inbound, only certain apps, only egress)
- Whether TLS inspection is in-scope

Recommended default:
- Threat Intel + IDPS enabled and tuned
- No TLS inspection by default unless you have enterprise CA distribution and a clear support model

## 6) Routing standards

Decide:
- UDR and forced-tunnel standards for spokes (symmetry for DNAT scenarios)
- Any transitive routing constraints (peering, NVA patterns, gateway transit)

Recommended default:
- Standard route tables per subnet role, managed by the platform team

## 7) Observability standards

Decide:
- Required diagnostic categories and retention
- Sentinel onboarding and alert ownership

Recommended default:
- All ingress + firewall diagnostics to a central Log Analytics workspace
- Minimum alert set: endpoint health degradation, WAF spikes, firewall deny spikes, backend 5xx spikes

## 8) Governance and exemptions

Decide:
- Which controls are Deny vs Audit
- How you request/approve policy exemptions

Recommended default:
- Deny clear anti-patterns (public IPs in workloads, open inbound NSG rules)
- Audit onboarding signals initially; add service-specific Deny policies where reliable

## 9) Application onboarding contract

Decide:
- Required inputs (DNS, certs, health probe path, backend type, risk rating)
- Lead time SLAs and change windows

Recommended default:
- A single onboarding form and a standard IaC-based pull request flow

## 10) DR drills and validation

Decide:
- Failover drill cadence
- Success criteria (time-to-failover, user journey validation)

Recommended default:
- Drill at least twice per year, with a documented postmortem and backlog of fixes
