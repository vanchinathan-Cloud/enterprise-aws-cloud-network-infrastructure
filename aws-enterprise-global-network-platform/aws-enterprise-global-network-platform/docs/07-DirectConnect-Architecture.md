# 07 - Direct Connect Architecture

## Topology
Each region has two Direct Connect locations (different facilities) with two dedicated connections each, terminating on separate customer routers (Cisco SD-WAN edge or WAN routers).

| Region | Colocation role | Connections (assumed) |
|---|---|---|
| APAC | Mumbai area, 2 DX locations | 2 x 10 Gbps per location |
| MEA | Dubai area, 2 DX locations | 2 x 10 Gbps per location |
| EU | Amsterdam, 2 DX locations | 2 x 10 Gbps per location |

Amsterdam DX locations serve the `eu-central-1` home region of the EU hub (Direct Connect locations connect to the nearest AWS region, not necessarily the one in the same city; confirm the parent region for each chosen facility).

## Virtual interfaces
- **Transit VIFs** to a Direct Connect gateway (one DX gateway for the network, associated with each regional Transit Gateway).
- Each connection carries a transit VIF; private VIFs are not used for workloads.
- BGP with BFD enabled, MD5 authentication, and MACsec where the location supports it.

```
On-prem / airports
   |  (172.16.0.0/12)
Cisco SD-WAN / WAN routers
   |  2 locations x 2 connections
Direct Connect transit VIFs
   |
Direct Connect Gateway (ASN 64600)
   |
Regional Transit Gateways (APAC, MEA, EU)
   |  peering + route table attachment
AWS Cloud WAN (segment: onprem)
```

## Routing
| Item | Design |
|---|---|
| AWS to on-premises | `172.16.0.0/12` learned over BGP |
| On-premises to AWS | DX gateway allowed prefixes: `10.10.0.0/16`, `10.20.0.0/16`, `10.30.0.0/16`, `10.40.0.0/16`, `10.50.0.0/16` |
| Primary vs backup | Local preference and AS-path prepending make DX primary; VPN (`192.168.0.0/24`) is backup |
| Regional preference | Each region prefers its local DX locations; cross-region path over Cloud WAN only on failure |

## Resilience model
Aim for the "maximum resiliency" pattern: two DX locations per region, each with redundant devices and connections. Failure of one connection, one device or one location does not interrupt service. Site-to-Site VPN over the internet is the last-resort path.

## Capacity and monitoring
- Alarm at 70% utilisation of any connection; add LAG members or upgrade before 80%.
- CloudWatch metrics `ConnectionState`, `ConnectionBpsEgress/Ingress`, and BGP state alarms feed the NOC.
- Quarterly failover tests (doc 12).

## Ownership
Direct Connect resources (connections, gateway, VIFs) are owned by the Network Account. Hosted connections via partners are an alternative where dedicated ports are not available at a site.
