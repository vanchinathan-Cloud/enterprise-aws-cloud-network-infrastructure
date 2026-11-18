# 11 - Network Security

## Layered controls
| Layer | Control |
|---|---|
| Governance | SCPs deny network-construct creation outside Network Account; region restriction |
| Segmentation | Cloud WAN segments, isolation by default, inspection between segments |
| Perimeter | Inspection VPC (Network Firewall, GWLB), centralised egress |
| Workload | Security groups (least privilege, referenced SGs and prefix lists), NACLs for coarse blocks |
| Application | AWS WAF and Shield Advanced on internet-facing ALB/CloudFront |
| DNS | Resolver DNS Firewall, query logging |
| Encryption | TLS in transit, MACsec on DX where available, IPsec on VPN, KMS at rest |
| Identity | IAM Identity Center, no long-lived keys, permission boundaries |

## Segmentation matrix (default)
| From \ To | prod | nonprod | dr | shared | security | onprem |
|---|---|---|---|---|---|---|
| prod | allow | deny | replication only | inspected | logs only | inspected |
| nonprod | deny | allow | deny | inspected | logs only | inspected |
| dr | replication only | deny | allow | inspected | logs only | inspected |
| shared | inspected | inspected | inspected | allow | logs only | inspected |
| onprem | inspected | inspected | inspected | inspected | restricted | n/a |

## Monitoring and detection
- VPC Flow Logs, Network Firewall logs, Resolver query logs, ALB logs, and CloudTrail go to the Log Archive in the Security account.
- GuardDuty, Security Hub, Inspector and Macie are enabled org-wide with the Security account as delegated administrator.
- Config conformance packs check for open security groups, IGWs in non-DMZ accounts, and unencrypted resources.
- SIEM ingests alerts; high-severity alerts page the 24x7 SOC.

## Compliance mapping
| Requirement | Control reference |
|---|---|
| PCI DSS segmentation | Dedicated `prod` payment accounts, inspection, firewall rule evidence |
| GDPR (EU) | EU data stays in the EU region; SCP region restriction; DLP monitoring |
| Audit | Immutable logs with object lock, 7-year retention |

## Incident response hooks
- Quarantine: tag-driven move of an attachment to an isolated `quarantine` segment (add it to the policy) or detach via runbook.
- Block: emergency deny rule in Network Firewall pushed through the pipeline with a fast-track approval.
- Forensics: traffic mirroring and flow-log analysis in the Security account.

## Reviews
Quarterly firewall rule review, semi-annual penetration test, annual SCP review, continuous Config compliance reporting.
