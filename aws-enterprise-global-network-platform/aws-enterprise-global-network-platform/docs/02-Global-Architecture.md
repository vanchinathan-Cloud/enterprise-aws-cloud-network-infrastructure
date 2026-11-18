# 02 - Global Architecture

## Overview
A hub-per-region design joined by an AWS Cloud WAN core network. Each region has a Network Account-owned core network edge (CNE), an Inspection VPC, Direct Connect gateway attachments and SD-WAN connect points. Workload accounts attach VPCs to Cloud WAN segments; they never peer or route directly.

```
                         AWS Cloud WAN Core Network (global)
        +------------------------+------------------------+
        |                        |                        |
   Edge: ap-south-1         Edge: me-central-1       Edge: eu-central-1
     (Mumbai)                 (Dubai)                 (EU hub)
        |                        |                        |
  Inspection VPC           Inspection VPC           Inspection VPC
  (GWLB + NFW)             (GWLB + NFW)             (GWLB + NFW)
        |                        |                        |
  Workload VPCs            Workload VPCs            Workload VPCs
  DX GW / TGW              DX GW / TGW              DX GW / TGW
  Cisco SD-WAN             Cisco SD-WAN             Cisco SD-WAN
        |                        |                        |
 Airports, offices,       Airports, offices,       Airports, offices,
 data centre              data centre              data centre
```

## Design principles
1. **Central network ownership:** Network Account owns Cloud WAN, TGWs, DX, IPAM, inspection.
2. **Segmentation by policy:** Cloud WAN segments, not per-VPC route tables.
3. **Inspect by default:** Cross-segment and internet traffic traverses Inspection VPC.
4. **Region autonomy:** Each region survives loss of the others and of the home region.
5. **Everything as code:** Terraform plus GitHub Actions; no console changes.

## Traffic flows
| Flow | Path |
|---|---|
| Workload to workload, same segment, same region | Cloud WAN, direct (no inspection unless segment requires) |
| Workload to workload, different segments | Cloud WAN, service insertion via Inspection VPC |
| Workload to internet | Cloud WAN, Inspection VPC egress, NAT, IGW |
| Workload to on-premises | Cloud WAN, TGW or DX gateway, Direct Connect (primary), SD-WAN/VPN (backup) |
| Region to region | Cloud WAN backbone, inspected per segment policy |
| User to AWS apps | SD-WAN, Direct Connect or Cloud WAN attachment, segment policy |

## Segments (summary; detail in doc 06)
`prod`, `nonprod`, `shared`, `security`, `onprem`, `dmz`.

## Key decisions
| Decision | Rationale |
|---|---|
| Cloud WAN as global core | Policy-driven, native multi-region, simpler than TGW peering mesh at 300+ accounts |
| Keep TGW for DX integration | Direct Connect transit VIFs terminate on DX gateway associated with TGW, which attaches to Cloud WAN (doc 08) |
| GWLB plus Network Firewall | GWLB for third-party appliance option and bump-in-wire; NFW for managed, AWS-native rules |
| EU hub in Frankfurt | No Amsterdam region |
