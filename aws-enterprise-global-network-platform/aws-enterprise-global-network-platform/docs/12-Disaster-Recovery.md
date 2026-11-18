# 12 - Disaster Recovery

## Objectives (assumed, to validate)
| Tier | Examples | RTO | RPO |
|---|---|---|---|
| Network core | Cloud WAN, DX, DNS, inspection | < 15 min | Config in code |
| Tier 1 | Departure control, reservations | < 1 h | < 5 min |
| Tier 2 | Crew, loyalty | < 4 h | < 1 h |
| Tier 3 | Analytics, internal tools | < 24 h | < 24 h |

## Failure scenarios and responses
| Failure | Impact | Response |
|---|---|---|
| Single DX connection or device | None | Redundant connection takes over |
| DX location loss | Reduced capacity | Second location carries traffic |
| All DX in a region | Region loses on-premises path | BGP shifts to VPN backup, then to other region over Cloud WAN |
| Inspection VPC AZ failure | None to degraded | Multi-AZ endpoints, flows pinned per AZ |
| Regional outage | Region unavailable | Other regions continue; DR workloads activate (below) |
| Control Tower home region (`ap-south-1`) outage | No new accounts or guardrail changes | Running workloads unaffected; changes wait or follow home-region recovery plan |
| Cloud WAN control-plane issue | No policy changes | Data plane keeps forwarding; freeze changes |
| Bad policy deployment | Broken routing | Roll back to previous policy version |

## DR design
- DR OU holds standby accounts mapped to the regional pairing: Mumbai and Dubai protect each other, Amsterdam/EU region protects with Dubai or Mumbai subject to data residency (EU data may need an EU DR region such as `eu-west-1`, confirm).
- DR VPCs use the `10.40.0.0/16` pool, attach to the `dr` segment, and are reachable only via inspection and replication paths.
- Pilot light for tier 2, warm standby for tier 1.
- DNS failover with Route 53 health checks and weighted or failover records.

## Network-as-code recovery
Because the network is Terraform-defined, a lost region's hub (inspection VPC, TGW, resolver endpoints) can be rebuilt by running the pipeline for that region. Target 30 to 60 minutes; practise it.

## Backups and state
- Terraform state in S3 with versioning, cross-region replication and DynamoDB locking, in the Shared Services account.
- Cloud WAN policy versions retained; export policy JSON in each release.
- Control Tower and AFT repos mirrored.

## Testing
| Test | Frequency |
|---|---|
| DX connection failover | Quarterly |
| Region isolation game day | Twice a year |
| Hub rebuild from code | Twice a year |
| DR workload failover | Annually per tier 1 app |
Record results, gaps and fixes in the runbook.
