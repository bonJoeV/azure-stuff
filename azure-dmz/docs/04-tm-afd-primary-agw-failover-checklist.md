# Ops Checklist – Front Door primary + AppGW failover via Traffic Manager

This checklist is for running the pattern where **Azure Front Door (AFD)** is primary, **Application Gateway (AppGW)** is secondary, with **Traffic Manager** in front controlling DNS failover.

## Why this pattern (explicit rationale)

**Goal:** reduce business impact if AFD becomes unavailable (regional/tenant/edge incident) by providing a secondary ingress path you can switch to.

**How it mitigates an AFD outage:**
- Traffic Manager continues to answer DNS queries.
- When the primary endpoint health probe fails, Traffic Manager returns the **secondary** endpoint.
- Clients that re-resolve DNS (or whose cache expires) begin using the secondary path.

**Important reality:** this is not instantaneous failover. It is bounded by:
- Traffic Manager probe cadence + fail thresholds
- DNS TTL you set
- Client/ISP DNS caching behavior

## Design decisions (must decide up front)

### 1) Hostname strategy
You have two viable approaches:
- **Same hostname on both paths (recommended for user experience)**
  - Example: `app.contoso.com` served by both AFD and AppGW
  - Requires cert + SNI parity and careful DNS strategy.
- **Break-glass hostname for secondary**
  - Example: `app-dr.contoso.com` points directly to AppGW
  - Faster to implement; worse UX during failover; app redirects/cookies may need changes.

### 2) Certificate strategy
- AFD: Managed certs or Key Vault-backed certs (org policy dependent)
- AppGW: Typically Key Vault integration

Checklist:
- Ensure the same SAN/CN is available to both endpoints if you want seamless failover.
- Ensure rotation process is defined (owners, cadence, automation).

### 3) WAF parity strategy
- AFD WAF and AppGW WAF are different engines and rule sets.

Checklist:
- Define a **baseline** policy for both (OWASP + bot rules where relevant).
- Maintain a single source of truth for exclusions/custom rules.
- Start Detection for new apps; move to Prevention after tuning.

### 4) Health probe design
Traffic Manager health probes are simplistic and do not validate “real user” flows.

Checklist:
- Use a dedicated health endpoint (e.g., `/healthz`) that validates upstream dependencies at the right depth.
- Avoid probes that trigger auth flows or costly backend calls.
- Ensure the probe path is reachable in both primary and secondary paths.

## Operational checklist

### Pre-production
- Confirm your DNS TTL (e.g., 30s) and document caching caveats.
- Confirm Traffic Manager routing method is **Priority**.
- Confirm both ingress stacks are tested end-to-end against the same backend pattern (Private Endpoints).
- Confirm backend access is private-only (no public IPs / public network access disabled).

### Monitoring & alerting
Minimum signals:
- Traffic Manager endpoint health (primary/secondary)
- AFD access logs + WAF logs
- AppGW access logs + WAF logs
- Azure Firewall DNAT hits + deny hits
- Backend health metrics (latency, 5xx rate)

Recommended alerts:
- “Primary endpoint unhealthy”
- “Traffic Manager returned secondary for > N minutes”
- “Spike in WAF blocks / false positives”
- “Firewall DNAT hits drop to zero unexpectedly”

### Failover drill (runbook)
- Plan: quarterly or at least semiannual drills.

Suggested drill steps:
1. Lower TTL ahead of time if needed.
2. Force primary down (disable AFD endpoint association or primary endpoint in Traffic Manager).
3. Validate DNS answers switch to secondary.
4. Validate user journey works (login, API calls, downloads).
5. Monitor WAF false positives on secondary.
6. Roll back to primary and confirm recovery.

### Post-failover review
- Confirm clients experienced expected time-to-recover (measure).
- Identify differences in WAF behavior between AFD/AppGW.
- Capture required policy changes and update IaC.

## Strong recommendation
Before adopting this pattern broadly:
- Evaluate whether **AFD multi-origin failover** meets your requirements (often simpler).
- Use this Traffic Manager pattern when you explicitly need a “second ingress control plane” to mitigate an AFD outage and you accept DNS limitations.
