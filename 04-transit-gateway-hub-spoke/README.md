# 04 — Transit Gateway Hub-and-Spoke

![Architecture Diagram](./architecture-diagram.svg)

## Overview
This module implements a hub-and-spoke network topology on AWS using Transit Gateway (TGW) as the central hub. Multiple VPCs ("spokes") attach to the TGW instead of peering with each other directly, giving a single, scalable point of control for routing, connectivity, and (optionally) inspection.

### Why Transit Gateway over VPC Peering
- **VPC Peering is not transitive** — with N VPCs you'd need up to N(N-1)/2 peering connections. TGW turns this into N attachments (one per VPC).
- **Centralized routing** — one or more TGW route tables control who can talk to whom, instead of managing route tables per peering connection.
- **Scales to on-prem and multi-region** — TGW also accepts Direct Connect Gateway and Site-to-Site VPN attachments, and can be peered across regions.

## Core Components

| Component | Purpose |
|---|---|
| **Transit Gateway (TGW)** | The regional hub resource that routes traffic between attachments. |
| **TGW Attachment** | Connects a VPC (via a subnet in each AZ), VPN, or Direct Connect Gateway to the TGW. |
| **TGW Route Table** | Controls which attachments can reach which CIDR ranges. You can have multiple route tables to segment traffic (e.g., prod vs. dev). |
| **VPC Route Table** | Each spoke VPC's subnet route table needs a route pointing non-local CIDRs at the TGW attachment (`tgw-xxxxxxxx`). |
| **Association vs. Propagation** | Association = which route table an attachment uses to route ITS traffic. Propagation = which route table LEARNS routes FROM that attachment. |

### Route Table Segmentation Patterns
1. **Single TGW route table (flat/full-mesh)** — every spoke can reach every other spoke. Simple but least isolation.
2. **Hub-and-spoke isolation** — spokes associate to a "spoke" route table that only propagates the hub's routes (not other spokes'). Spokes can reach the hub (and, through it, shared services or on-prem) but not each other.
3. **Segmented (e.g., prod isolated from dev/test)** — multiple route tables, selectively propagating only the CIDRs that should be reachable — useful for compliance boundaries.

## Build Steps

1. **Create the VPCs** — hub + spoke(s), each with non-overlapping CIDR blocks (critical — TGW does not do NAT/overlap resolution).
2. **Create the Transit Gateway.**
3. **Create TGW attachments** — one per VPC, selecting a subnet in each AZ you want reachable.
4. **Create TGW route table(s)** — e.g., `rt-hub`, `rt-spoke` — and set:
   - Associations: which attachment uses which route table.
   - Propagations: which attachments' CIDRs get auto-added as routes.
5. **Update VPC subnet route tables** — add a route for the other VPCs' CIDRs (or `0.0.0.0/0` if routing all egress through the hub) with target the TGW.
6. **Security Groups / NACLs** — TGW does not filter traffic itself (unless paired with AWS Network Firewall); enforce isolation at the VPC/instance layer too.
7. **Test connectivity** — e.g., ping/curl between instances in different spokes, and confirm blocked paths actually fail (spoke-to-spoke if that's supposed to be denied).

## Lessons Learned

- CIDR ranges across all VPCs must not overlap.
- A VPC route table entry pointing at the TGW only takes effect for subnets actually listed in that route table — worth checking every subnet that needs it.
- TGW attachments need a subnet in each AZ you want to route through, for HA; missing an AZ means instances there can't use the attachment.
- Both directions matter: spoke → hub/other-spoke and the return route back — missing either direction causes asymmetric routing or blackholed traffic.
- Data transfer through TGW is billed per GB plus a per-attachment hourly charge — worth factoring into any cost estimate.
- If a firewall/NVA is added in the hub VPC for inspection, an additional "inspection" TGW route table is needed so traffic routes through the appliance rather than directly hub-to-spoke.
- **Once you've completed this lab, delete the resources you created** — EC2 instances, TGW attachments, and the Transit Gateway itself (which has an hourly charge per attachment) — otherwise this will keep charging your AWS account every month.

## Validation Checklist

- [ ] Instance in Spoke A can reach instance in Spoke B (if allowed)
- [ ] Instance in Spoke A cannot reach Spoke C (if isolation intended)
- [ ] Spoke instances can reach shared services in the hub VPC
- [ ] On-prem (VPN/DX) can reach permitted spoke CIDRs
- [ ] Route tables show expected propagated routes (`aws ec2 get-transit-gateway-route-table-propagations`)
- [ ] No unintended `0.0.0.0/0` propagation exposing spokes to each other
