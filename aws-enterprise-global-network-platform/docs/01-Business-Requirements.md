# 01 - Business Requirements

## Context
A global airline with 50,000+ users (corporate, airport operations, crew, call centres) and 300+ AWS accounts hosting workloads such as reservations, departure control, crew management, loyalty, and analytics. Three regional hubs: Mumbai (APAC), Dubai (MEA), Amsterdam area (EU).

## Business drivers
- Operational continuity: airport and flight operations run 24x7; network outages ground flights.
- Regional autonomy with global governance.
- Regulatory compliance: PCI DSS (payments), GDPR (EU passenger data), UAE and India data-protection rules, IATA/airline security expectations.
- Faster onboarding of new accounts and business units (days, not weeks).
- Predictable networking cost.

## Functional requirements
| ID | Requirement |
|---|---|
| FR-1 | Any-to-any private connectivity between regions, subject to segmentation policy |
| FR-2 | Private connectivity from airports, offices and data centres via Cisco SD-WAN and Direct Connect |
| FR-3 | Central inspection of north-south and inter-segment traffic |
| FR-4 | Hybrid DNS resolution between on-premises and all AWS accounts |
| FR-5 | Non-overlapping, centrally managed IP addressing |
| FR-6 | Self-service account vending with baseline network and security guardrails |
| FR-7 | All infrastructure deployed as code via CI/CD |

## Non-functional requirements
| Category | Target (assumed, to validate) |
|---|---|
| Availability | 99.99% for core network services |
| RTO / RPO | Network: RTO < 15 min, RPO n/a (config in code); tier-1 apps per doc 12 |
| Latency | Intra-region < 5 ms, inter-region per AWS backbone |
| Security | Zero-trust segmentation, encrypted in transit, full flow logging |
| Scalability | 1,000 accounts and 3 to 5 regions without redesign |
| Auditability | Immutable logs retained 7 years |

## Constraints
- Existing Cisco SD-WAN estate is retained.
- Control Tower home region fixed to `ap-south-1`.
- AWS has no Amsterdam region; EU hub uses `eu-central-1`.
- Mandatory governance through Organizations and SCPs.

## Success criteria
- New account has compliant networking in under one day.
- Zero overlapping CIDRs.
- 100% of inter-segment traffic inspected.
- Failover tested twice a year with documented results.

## Open questions
1. Data-residency rules for crew and passenger data per region?
2. Existing on-premises address space and DNS zones?
3. Bandwidth per airport and data-centre site?
4. Is a fourth region (Americas) planned?
