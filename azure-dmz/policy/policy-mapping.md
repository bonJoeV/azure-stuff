# Policy mapping (policy → risk mitigated)

| Policy | Effect | Risk mitigated |
|---|---|---|
| Deny creation of Public IP addresses | Deny | Prevents accidental direct internet exposure from workload subscriptions |
| Deny NICs with Public IP association | Deny (parameterized) | Prevents attaching pre-existing public IPs to NICs (closes a common loophole) |
| Deny NSG inbound rules allowing 0.0.0.0/0 | Deny | Reduces broad inbound exposure and enforces least privilege |
| Require Key Vault public network access disabled | Deny (parameterized) | Prevents direct internet reachability to Key Vault |
| Audit Key Vaults not using RBAC authorization | Audit (parameterized) | Flags inconsistent authorization model that can complicate enterprise governance |
| Enforce Storage Account baseline (private-only + TLS) | Deny (parameterized) | Prevents public access and weak transport posture on storage |
| Require App Service public network access disabled | Deny (parameterized) | Prevents direct internet reachability to App Service |
| Require Azure SQL Server public network access disabled | Deny (parameterized) | Prevents direct internet reachability to Azure SQL logical servers |
| Require Cosmos DB public network access disabled | Deny (parameterized) | Prevents direct internet reachability to Cosmos DB |
| Require Container Registry public network access disabled | Deny (parameterized) | Prevents direct internet reachability to ACR |
| Require API Management public network access disabled | Deny (parameterized) | Prevents direct internet reachability to APIM |
| Require AKS private cluster | Audit (parameterized) | Flags clusters with public control plane exposure |
| Audit resources not using Private Endpoints (tag signal) | Audit | Detects workloads not onboarded to private-only connectivity patterns |
| Deploy diagnostic settings to Log Analytics (scaffold) | DeployIfNotExists | Ensures security/ops telemetry exists for incident response and auditing |
| Audit DDoS enabled on hub VNets (tag scope) | Audit | Detects hub VNets without DDoS protection enabled |
| Audit workloads not fronted by approved WAF (tag signal) | Audit | Detects workloads that bypass centralized ingress/WAF standards |

## Notes
- The tag-based policies are intentionally broad and work across heterogeneous workloads; in mature environments they are often paired with:
  - Resource-type-specific policies (e.g., require `publicNetworkAccess=Disabled` for PaaS)
  - CMDB-driven onboarding checks
  - Azure Resource Graph reporting and exceptions workflow
