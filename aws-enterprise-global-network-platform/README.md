# AWS Enterprise Global Network Platform

Reference architecture for a global airline running 300+ AWS accounts and 50,000+ users across APAC, MEA and EU, connected through Cisco SD-WAN, AWS Direct Connect and AWS Cloud WAN.

## Scope

| Area | Choice |
|---|---|
| Regions | APAC - Mumbai (`ap-south-1`), MEA - Dubai (`me-central-1`), EU - Amsterdam area (`eu-central-1`, see note) |
| Users / accounts | 50,000+ / 300+ |
| Connectivity | Cisco SD-WAN, AWS Direct Connect, AWS Cloud WAN |
| Governance | AWS Control Tower, AWS Organizations, SCPs |
| Network security | Gateway Load Balancer, AWS Network Firewall, Inspection VPC |
| DNS | Route 53 Resolver, Private Hosted Zones |
| Automation | Terraform, GitHub Actions |

> **Region note:** AWS has no Amsterdam region. The EU hub is placed in `eu-central-1` (Frankfurt) for the lowest latency to Amsterdam with full service coverage; `eu-west-1` (Ireland) is the alternative. Amsterdam remains the Direct Connect and SD-WAN colocation site. Confirm data-residency requirements before finalising.

## Documentation

| # | Document | Purpose |
|---|---|---|
| 01 | [Business Requirements](docs/01-Business-Requirements.md) | Drivers, constraints, success criteria |
| 02 | [Global Architecture](docs/02-Global-Architecture.md) | End-to-end design |
| 03 | [AWS Organizations](docs/03-AWS-Organizations.md) | OU and account model, SCPs |
| 04 | [Control Tower Landing Zone](docs/04-Control-Tower-Landing-Zone.md) | Guardrails, account vending |
| 05 | [IPAM / CIDR Strategy](docs/05-IPAM-CIDR-Strategy.md) | Address plan |
| 06 | [Cloud WAN Architecture](docs/06-CloudWAN-Architecture.md) | Core network, segments, policy |
| 07 | [Direct Connect Architecture](docs/07-DirectConnect-Architecture.md) | Private connectivity |
| 08 | [Transit Gateway Integration](docs/08-TransitGateway-Integration.md) | TGW and Cloud WAN coexistence |
| 09 | [Hybrid DNS](docs/09-Hybrid-DNS-Architecture.md) | Resolver and PHZ design |
| 10 | [Inspection VPC](docs/10-Inspection-VPC.md) | GWLB, Network Firewall |
| 11 | [Network Security](docs/11-Network-Security.md) | Controls and monitoring |
| 12 | [Disaster Recovery](docs/12-Disaster-Recovery.md) | Failure and recovery design |
| 13 | [Operations Runbook](docs/13-Operations-Runbook.md) | Day-2 procedures |
| 14 | [Cost Optimization](docs/14-Cost-Optimization.md) | FinOps levers |

## Repository layout

```
aws-enterprise-global-network-platform/
├── README.md
├── docs/                         # design documents 01-14
├── terraform/                    # network platform code (see terraform/README.md)
│   ├── ipam.tf                   # IPAM pools from the address plan
│   ├── cloudwan.tf               # core network, segments, policy, DX gateway
│   ├── hubs.tf                   # three regional hubs
│   └── modules/regional-hub/     # inspection VPC, Network Firewall, GWLB, DNS, TGW, RAM
└── .github/workflows/terraform.yml   # validate, plan on PR, gated apply
```

Landing-zone code (Control Tower, AFT, SCPs) is intended for a sibling repository, `landing-zone-terraform`.

## Address plan

| Range | Use |
|---|---|
| `10.10.0.0/16` | Production |
| `10.20.0.0/16` | Shared |
| `10.30.0.0/16` | Non-production |
| `10.40.0.0/16` | DR |
| `10.50.0.0/16` | Security |
| `172.16.0.0/12` | On-premises via Direct Connect |
| `192.168.0.0/24` | VPN |

Each environment `/16` is split into `/18` blocks per region (see doc 05).

## Status

Design baseline v0.1. Sizing and bandwidth figures are starting assumptions. The Terraform has not been run or validated against a live account: run `terraform validate` and review a plan in a sandbox first.
