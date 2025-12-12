# 4) Operating Model – “Ingress as a Service”

## A. Service ownership

**Platform team owns**
- Hub/Connectivity subscription(s) and network architecture
- Azure Firewall Premium + Firewall Policy (rule lifecycle, threat intel, IDPS)
- Ingress tier (Azure Front Door *or* Application Gateway WAF v2) configuration, WAF policies
- DDoS Network Protection plan and protected resources governance
- Private DNS zones strategy + linking
- Central logging (Log Analytics), Microsoft Sentinel onboarding (if used)
- Guardrails (Azure Policy) and exemptions management

**Application teams own**
- Workload subscription resources (apps, PaaS/IaaS services)
- Private Endpoints for each backend (created in spoke VNets)
- App-level authN/authZ (Entra ID, mTLS where required), secrets and certificates for app components
- Observability for app-specific signals and dashboards (aligned to platform standards)

### RACI (summary)

| Activity | Platform team | App Team | SecOps |
|---|---:|---:|---:|
| Define ingress patterns/standards | R | C | A |
| Create/maintain WAF baseline | R | C | A |
| Add onboarding rules/routes | R | C | C |
| Manage cert lifecycle (platform edge) | R | C | C |
| Private Endpoint creation (spoke) | C | R | C |
| Incident response for platform ingress | R | C | A |
| Cost allocation/chargeback | R | C | C |

Legend: R=Responsible, A=Accountable, C=Consulted

## B. Request intake

### Request process
1. App team submits an “Ingress as a Service” request.
2. Platform team validates network readiness and guardrail compliance.
3. Security review for external exposure and WAF requirements.
4. Platform team implements/approves routing and firewall rules.
5. App team validates end-to-end, then platform team enables production traffic.

### Required inputs
- Application name, owner, subscription, environment (dev/test/prod)
- Public hostname(s) and certificate requirements (SANs, key size, rotation window)
- Backend type: App Service, AKS, VM, API Management, Storage, etc.
- Backend connectivity: Private Endpoint details, target FQDN(s), health probe path
- Authentication model (OIDC, mTLS, IP allowlist requirements)
- Data classification and risk rating
- Required WAF behavior (block/log mode, exclusions, custom rules)

### Approval workflow (minimal)
- App team manager approval
- Platform team approval (architecture + ops readiness)
- Security approval (risk acceptance if needed)

## C. Lifecycle management

### Onboarding
- Establish DNS and certificate plan
- Confirm Private Endpoint and Private DNS resolution
- Implement routing + WAF policy association
- Implement Firewall rules (least privilege)
- Enable diagnostics to Log Analytics

### Change management
- All ingress changes tracked via IaC pull request
- Emergency changes allowed with post-change review within 24–48h

### Certificate rotation
- Managed certificates where supported; otherwise store certs in Key Vault
- Rotate before expiry (recommended 30–60 days)
- Validate staging slot or pre-prod before swapping

### WAF rule tuning
- Start in detection mode where appropriate; move to prevention after tuning
- Maintain allowlists/exclusions with justification and expiry

### Decommissioning
- Remove routes/listeners
- Remove firewall rules
- Remove DNS records
- Confirm no remaining public dependencies

## D. Runbooks (high level)

### Application onboarding runbook
- Validate prerequisites (Private Endpoint, DNS, health probes)
- Deploy/merge IaC changes
- Smoke test (HTTP 200, auth, performance baseline)
- Enable WAF prevention mode (if required)

### Incident response runbook
- Identify scope (Front Door/AppGW logs, Firewall logs)
- Block malicious IPs/ASNs/signatures
- Triage backend health vs edge failures
- Engage app team when backend errors observed

### Emergency traffic blocking
- Immediate: WAF custom rule block by IP/geo/path
- Next: Firewall deny rule for destination
- After: post-incident review and permanent control

### DR / regional failover
- Define RTO/RPO per workload
- Ensure ingress configuration supports secondary region
- Validate Private Endpoint + DNS patterns for failover (workload-dependent)

## E. KPIs & guardrails

**Security KPIs**
- % workloads with no public IPs (target 100%)
- WAF blocked requests per app and false-positive rate
- Firewall deny hits and IDPS alerts

**Reliability KPIs**
- Ingress availability (SLO)
- P95 latency edge→origin
- Change failure rate for ingress updates

**Cost / chargeback**
- Shared platform costs allocated by request volume, bandwidth, or number of listeners/routes
