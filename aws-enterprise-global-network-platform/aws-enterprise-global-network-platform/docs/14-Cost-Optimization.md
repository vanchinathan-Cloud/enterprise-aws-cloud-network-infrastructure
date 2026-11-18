# 14 - Cost Optimization

## Main cost drivers
| Driver | Notes |
|---|---|
| Cloud WAN edges and attachments | Hourly per edge and per attachment, plus data processing |
| Transit Gateway | Hourly per attachment plus per-GB processing |
| Network Firewall | Hourly per endpoint plus per-GB processing |
| NAT gateways | Hourly plus per-GB; large egress volume |
| Direct Connect | Port hours and data transfer out |
| Inter-region and inter-AZ transfer | Cross-region traffic over Cloud WAN, inter-AZ in inspection |
| Interface VPC endpoints | Hourly per AZ |
| Resolver endpoints | Hourly per ENI plus per-query |

Check current AWS pricing for exact rates; this document lists levers, not prices.

## Levers
1. **Keep traffic local:** prefer in-region data paths, place chatty systems in the same region, and avoid hairpinning through other regions.
2. **Right-size inspection:** inspect only segment pairs that need it; allow trusted high-volume flows (for example backup replication on known ports) by policy rather than bypass.
3. **Direct Connect for bulk:** move large data transfers from internet/NAT paths to DX where data-transfer-out rates are lower.
4. **Centralise shared endpoints:** one set of interface endpoints (S3 gateway endpoints are free) and shared NAT in the hub instead of per-account copies, balanced against blast radius.
5. **Reduce attachments:** consolidate small accounts into fewer VPCs where isolation allows; delete unused attachments through lifecycle automation.
6. **Reduce NAT cost:** S3 and DynamoDB gateway endpoints, ECR and package mirrors in Shared Services.
7. **Commitments:** Savings Plans and reserved capacity for appliance fleets under GWLB; right-size appliance instances.
8. **Resolver tuning:** consolidate endpoints, cache aggressively, remove unused rules.
9. **Sandbox controls:** budgets and SCPs that block network constructs and large resources in the Sandbox OU.

## Allocation and visibility
- Cost allocation tags: `CostCenter`, `Application`, `Environment`, `Region-Domain`.
- Shared network costs charged back by attachment count and data processed, using CUR plus Athena or Cost Explorer, by account and segment.
- Budgets with alerts per OU; anomaly detection on data-transfer line items.

## KPIs
| KPI | Target |
|---|---|
| Network cost per user per month | Track trend, set baseline in first quarter |
| Inter-region transfer as % of network cost | Decreasing |
| Unused attachments / idle endpoints | Zero older than 30 days |
| NAT data processed per account | Review top 10 monthly |

## Review cadence
Monthly FinOps review with network, platform and application owners; quarterly commitment review.
