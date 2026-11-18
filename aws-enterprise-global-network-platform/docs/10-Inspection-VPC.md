# 10 - Inspection VPC

## Purpose
Central inspection of inter-segment, on-premises and internet-bound traffic in each region, using AWS Network Firewall (managed rules) and Gateway Load Balancer (for third-party or custom appliances).

## Layout (per region, Shared pool `/24`)
| Subnet | Per AZ | Contents |
|---|---|---|
| Cloud WAN attachment | `/28` | Cloud WAN VPC attachment ENIs (appliance mode on) |
| Firewall | `/28` | Network Firewall endpoints |
| NAT / egress | `/28` | NAT gateways for internet egress |
| GWLB / appliance (optional) | `/28` | GWLB endpoints, enabled with `enable_gwlb` |

Two AZs in the reference Terraform. Route 53 Resolver endpoints do not live here: they sit in a separate DNS hub VPC (`/26`, segment `shared`, doc 09) so on-premises DNS can reach them without crossing the inspection path.

## Traffic path
```
Source VPC -> Cloud WAN (service insertion, network function group "inspection")
   -> Inspection VPC attachment subnet
   -> Network Firewall endpoint (stateful + stateless rules)
   -> (optional) GWLB -> third-party appliance (IDS/IPS, TLS inspection)
   -> back to attachment subnet -> Cloud WAN -> destination
```
Internet egress: after inspection, traffic goes to NAT gateway then IGW in the inspection VPC. Ingress from internet uses the `dmz` or edge design with ALB/WAF in the owning account, then inspection.

## Network Firewall policy
| Rule group | Type | Examples |
|---|---|---|
| Stateless | Pass or forward to stateful | Forward all by default |
| Stateful domain list | Allow list | Approved SaaS, OS update domains, payment gateways |
| Stateful Suricata | IPS signatures | Managed threat-signature groups |
| Segment rules | 5-tuple | prod must not reach nonprod; DR to prod only on replication ports |

`HOME_NET` = the five environment `/16`s plus `172.16.0.0/12` and `192.168.0.0/24`.

## GWLB option
Use GWLB where the airline's security standard requires a third-party NGFW. Appliances sit in an Auto Scaling group behind GWLB, in the appliance subnets, with health checks and cross-zone load balancing disabled by default to keep flows in AZ.

## Resilience and scale
- Endpoint per AZ; flow symmetry through appliance mode.
- Firewall capacity auto-scales; alarm on `DroppedPackets`, `ReceivedPackets` and capacity headroom.
- Fail-open versus fail-closed: fail-closed for prod/onprem segments; documented exception process for emergency bypass (doc 13).

## Logging
Alert and flow logs to S3 and CloudWatch in the Security account; Suricata alerts forwarded to the SIEM.
