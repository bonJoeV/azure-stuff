# 1) Reference Architecture – Centralized DMZ / Ingress

## Management groups & subscriptions (logical)

- **Tenant Root Group**
  - **Platform (MG)**
    - **Connectivity subscription (Hub)**
      - Hub VNet
      - Azure Firewall Premium + Firewall Policy
      - (Optional) shared services (Private DNS, Private Resolver)
      - Log Analytics workspace
      - DDoS Network Protection plan association
    - **Management subscription** (optional split)
      - Sentinel (if used), central monitoring, update management
  - **Landing Zones (MG)**
    - **Workload subscriptions (Spokes)**
      - Application VNets / workloads
      - Private Endpoints only
      - No public IPs

## A. Preferred ingress: Azure Front Door (Standard/Premium) + Firewall + Private Endpoints

### Text-based diagram (draw.io / Visio-ready)

```
[Internet]
   |
   v
[Azure Front Door Std/Prem]
  - WAF policy (edge)
  - Custom domain + cert
   |
   | (HTTPS to origin)
   v
[Azure Firewall Premium - Public IP]
  - DNAT (L4) to internal VIP / backend
  - Threat intel / IDPS
  - (Optional) TLS inspection (enterprise CA, supported scenarios only)
   |
   | (forwarded traffic)
   v
[Hub VNet]
  |  \
  |   \__ (VNet peering, allow forwarded traffic)
  |
  +--> [Private Endpoint (Spoke VNet)] ---> [Workload (PaaS/IaaS)]

Logging:
- Front Door diagnostics -> Log Analytics
- Firewall diagnostics -> Log Analytics
- Workload diagnostics -> Log Analytics
- Sentinel (optional) reads from Log Analytics

DNS:
- Private DNS zones hosted centrally (Hub) and linked to Spoke VNets
- Workloads resolve privatelink FQDNs to Private Endpoint IPs
```

### Traffic flow (requested explicit path)

1. **Internet → Front Door**
   - Front Door terminates TLS and applies **WAF** at the edge.
2. **Front Door → Azure Firewall public IP (origin)**
   - Front Door connects to the Firewall’s public IP over HTTPS.
   - Firewall uses **DNAT** to forward traffic to the next hop in the hub/spoke network.
3. **Firewall → Private Endpoint → Workload**
   - Traffic is routed (UDR + peering) from hub to the spoke where the **Private Endpoint** lives.
   - Workload is reachable only via its Private Endpoint.

### Important constraints / trade-offs

- **Front Door is an edge service**. For many designs, the most supportable private-origin approach is:
  - **Front Door Premium Private Link Origin** → private origin directly.
  - This *does not naturally “hairpin” through Azure Firewall*.
- The “Front Door → Firewall → Private Endpoint” chain can be implemented using **Firewall public IP as an origin with DNAT**, but you should validate:
  - Required header preservation / client IP requirements
  - TLS termination locations (WAF vs inspection)
  - Operational complexity and troubleshooting
- If “Firewall must always be inline for all inbound” is a hard requirement, the **Application Gateway option** is often more straightforward.

## B. Alternative ingress: Application Gateway (WAF v2) + Firewall + Private Endpoints

### Text-based diagram (draw.io / Visio-ready)

```
[Internet]
   |
   v
[Public IP]
   |
   v
[Application Gateway WAF v2 (Hub)]
  - WAF policy
  - TLS termination / end-to-end TLS
  - Listener rules / path routing
   |
   v
[Azure Firewall Premium (Hub)]
  - UDR forces AppGW subnet egress via Firewall
  - IDPS / Threat intel
   |
   v
[Private Endpoint (Spoke)] ---> [Workload]

DNS:
- Private DNS zones linked to Hub + Spokes
- AppGW resolves backend FQDNs to Private Endpoint IPs
```

### Traffic flow (requested explicit path)

1. **Internet → Application Gateway (WAF v2)**
2. **Application Gateway → Azure Firewall** (forced via UDR)
3. **Firewall → Private Endpoint → Workload**

## DNS resolution flow (Private DNS zones)

- Private Endpoints rely on `privatelink.*` zones (service-specific).
- Recommended centralized pattern:
  - Create Private DNS zones in the **Connectivity** subscription.
  - Link zones to:
    - Hub VNet (so shared services/ingress can resolve)
    - Spoke VNets (so workloads resolve their own PEs)
  - If on-premises resolution is required, add **Azure DNS Private Resolver** in the hub (optional).

## Logging / Monitoring integration

- **Diagnostic settings** to Log Analytics for:
  - Azure Firewall + Firewall Policy
  - Application Gateway (if used)
  - Front Door (if used)
  - VNets / DDoS (where supported)
- Sentinel (optional): enable solutions/analytics rules aligned to ingress and firewall events.

## Security controls summary

- **WAF** (Front Door or App Gateway): L7 protection, OWASP, bot protection (capability varies by service/SKU).
- **Azure Firewall Premium**: centralized allow-listing, IDPS, threat intel, optional TLS inspection (requires enterprise CA and careful design).
- **DDoS Network Protection**: protects public endpoints in the protected VNet.
- **Private Endpoints only**: eliminates direct public exposure of workload services.
- **Policy guardrails**: block public IPs, block 0.0.0.0/0 inbound, enforce diagnostics.

## Optional: Front Door primary, App Gateway failover with Traffic Manager out front

### Why you might do this
- You want an additional “control plane” for failover if you consider an edge dependency (Front Door) a business risk.
- You want a regional ingress (App Gateway) you can direct traffic to during an edge outage or tenant-wide incident.

### Text-based diagram

```
[Client]
  |
  v
[Traffic Manager (Priority)]  (DNS-based failover)
  | primary: <endpoint>.azurefd.net
  | secondary: App Gateway public IP (regional)
  |
  +--> [Azure Front Door + WAF] ---> [Azure Firewall public IP (DNAT)] ---> [Private Endpoint] ---> [Workload]
  |
  +--> [App Gateway WAF v2] --(UDR)--> [Azure Firewall] ---> [Private Endpoint] ---> [Workload]
```

### Key constraints (important for ops expectations)
- **Failover is DNS-based**: TTL + client DNS caching means failover can take minutes, not seconds.
- **Certificates & hostname**: both Front Door and App Gateway must be able to serve the same application hostname and cert chain (or you need a planned “break glass” hostname).
- **Policy/WAF parity**: you must maintain equivalent WAF baselines and exceptions in two different WAF engines.
- **Health checks differ**: Traffic Manager health checks are not equivalent to end-user experience; choose probe paths carefully.

### Practical recommendation
- Prefer **Front Door’s built-in multi-origin/multi-region failover** for most enterprise cases.
- Use Traffic Manager + App Gateway as a deliberate “break glass” failover pattern when you have a clear operational requirement and accept DNS limitations.
