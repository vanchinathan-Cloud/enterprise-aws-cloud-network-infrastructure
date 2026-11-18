# 05 - IPAM / CIDR Strategy

## Principles
- One address block per environment, split by region, managed by AWS VPC IPAM in the Network Account (delegated administrator) and shared through RAM.
- No overlaps with on-premises (DX range) or VPN ranges; IPAM reserves those ranges so conflicts are flagged.
- VPCs get right-sized blocks from IPAM pools; CIDRs are never hand-picked.

## Environment address plan
| Environment | CIDR | Notes |
|---|---|---|
| Production | `10.10.0.0/16` | Mumbai, Dubai, EU production VPCs |
| Shared | `10.20.0.0/16` | Shared services, network hub VPCs, inspection, DNS |
| Non-production | `10.30.0.0/16` | Dev, test, staging |
| DR | `10.40.0.0/16` | DR OU workloads |
| Security | `10.50.0.0/16` | Security tooling, logging |
| Direct Connect (on-premises) | `172.16.0.0/12` | Reserved. Reached over DX; never allocated to AWS VPCs |
| VPN | `192.168.0.0/24` | Reserved. Backup VPN and remote-access ranges |

## Regional split inside each environment `/16`
Each environment `/16` is divided into four `/18` blocks (16,384 addresses each):

| Slot | Production | Shared | Non-prod | DR | Security |
|---|---|---|---|---|---|
| Mumbai (`ap-south-1`) | `10.10.0.0/18` | `10.20.0.0/18` | `10.30.0.0/18` | `10.40.0.0/18` | `10.50.0.0/18` |
| Dubai (`me-central-1`) | `10.10.64.0/18` | `10.20.64.0/18` | `10.30.64.0/18` | `10.40.64.0/18` | `10.50.64.0/18` |
| EU (`eu-central-1`) | `10.10.128.0/18` | `10.20.128.0/18` | `10.30.128.0/18` | `10.40.128.0/18` | `10.50.128.0/18` |
| Spare | `10.10.192.0/18` | `10.20.192.0/18` | `10.30.192.0/18` | `10.40.192.0/18` | `10.50.192.0/18` |

The spare `/18` is held back for a fourth region or for growth in a busy region.

## Pool hierarchy
```
Top-level pool (private scope)       provisioned: 10.10/16, 10.20/16, 10.30/16, 10.40/16, 10.50/16
├── prod pool        10.10.0.0/16
│   ├── ap-south-1   10.10.0.0/18
│   ├── me-central-1 10.10.64.0/18
│   └── eu-central-1 10.10.128.0/18
├── shared pool      ... same pattern
├── nonprod pool
├── dr pool
└── security pool
```
Regional pools carry a locale so a VPC can only draw from the pool of its own region.

## Capacity check (important)
| Pool | Size | `/24` VPCs | `/22` VPCs |
|---|---|---|---|
| Production per region (`/18`) | 16,384 | 64 | 16 |
| Production total (`/16`) | 65,536 | 256 (3 regions: 192) | 64 |

With 300+ accounts, a single `/16` for production is tight if every account has its own VPC. Options:
1. Use `/26` to `/25` VPCs for small accounts, `/24` or larger only by exception.
2. Use the spare `/18` and, if needed, add more production blocks (for example `10.11.0.0/16`) to the top-level pool.
3. Use `100.64.0.0/10` secondary CIDRs for container pods behind NAT.

Decision to confirm with the airline: expected VPCs per region and per-account sizing.

## VPC sizing tiers
| Tier | Netmask | Use |
|---|---|---|
| Small | `/26` | Single small app |
| Medium | `/24` | Typical workload account |
| Large | `/22` | Data and container platforms (exception, approval required) |
| Hub | `/24` | Inspection and DNS VPC in Shared pool |

## IPAM rules
- Allowed netmask length per pool: min `/26`, max `/22` (hub `/24`).
- `auto_import = false` on prod pools; compliance monitoring raises overlap alerts.
- Allocations created by Terraform/AFT and released on account decommission.
- On-premises (`172.16.0.0/12`) and VPN (`192.168.0.0/24`) ranges are documented in `terraform/` variables and used in firewall `HOME_NET`, route filters and security-group prefix lists.

## Routing summary
| Direction | Prefix |
|---|---|
| AWS to on-premises | `172.16.0.0/12` via Direct Connect (primary) |
| AWS to VPN clients/sites | `192.168.0.0/24` via VPN (backup path) |
| On-premises to AWS | `10.10.0.0/16`, `10.20.0.0/16`, `10.30.0.0/16`, `10.40.0.0/16`, `10.50.0.0/16` advertised through DX gateway allowed prefixes |

Summarise to the five `/16`s on Direct Connect to stay under the 20-prefix limit for a transit VIF advertisement.
