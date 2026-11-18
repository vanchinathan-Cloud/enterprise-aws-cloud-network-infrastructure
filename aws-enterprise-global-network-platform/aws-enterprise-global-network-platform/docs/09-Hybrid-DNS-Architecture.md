# 09 - Hybrid DNS Architecture

## Goals
Resolve on-premises names from every AWS account and AWS private names from on-premises, with a single set of rules managed centrally.

## Design
```
On-premises DNS (corp.airline.example)
     ^                         |
     | forward to on-prem      | forward aws.airline.example
     |                         v
Outbound endpoint  <----  Inbound endpoint     (Route 53 Resolver, Network Account hub VPC, per region)
     ^
     | rules shared via RAM
Workload VPCs (all accounts) -- Resolver rules associated by AFT
```

| Component | Placement |
|---|---|
| Inbound endpoints | Hub VPC in each region, 2+ AZs; on-premises DNS forwards `aws.airline.example` here |
| Outbound endpoints | Same hub VPC; forwarding rules to on-premises DNS servers |
| Resolver rules | Created in the Network Account, shared with the organization via RAM |
| Private Hosted Zones | Per domain/application in owning accounts, associated cross-account to the hub and spoke VPCs |

## Zone naming (assumed, replace with airline domains)
| Zone | Purpose |
|---|---|
| `corp.airline.example` | On-premises, forwarded out |
| `aws.airline.example` | Root for AWS private zones |
| `prod.aws.airline.example`, `nonprod.aws.airline.example` | Environment zones |
| `<region>.aws.airline.example` | Regional service endpoints |

## Rules
- Forwarding rule `corp.airline.example` to on-premises DNS IPs (in `172.16.0.0/12`) on port 53, via outbound endpoint, with at least two targets per region.
- Rules associated to each VPC automatically by AFT; manual association is blocked.
- Cross-account PHZ association uses the authorization/association API through Terraform.
- Interface VPC endpoints use private DNS; centralise shared endpoints in the Shared pool where cost justifies it.
- Route 53 Resolver DNS Firewall in the hub and spokes with AWS managed domain lists plus a custom block list.
- Query logging to the Security account.

## Resilience
Endpoints in two AZs per region; on-premises forwarders point to the inbound endpoints of two regions (local first). Each region keeps its own resolver rules so a regional outage does not stop DNS elsewhere.

## Capacity
Each resolver endpoint ENI handles about 10,000 queries per second; add ENIs if sustained load nears 70%. Watch `InboundQueryVolume` and `OutboundQueryVolume`.
