# 03 - AWS Organizations

## OU structure
```
Root
├── Security OU
│   └── Security Account (Audit + Log Archive roles, GuardDuty/Security Hub delegated admin)
├── Infrastructure OU
│   ├── Network Account (Cloud WAN, TGW, DX, IPAM, Route 53 Resolver, Inspection VPCs)
│   └── Shared Services Account (CI runners, artifact stores, AD, DNS forwarders, tooling)
├── Production OU
│   ├── Mumbai Account(s)   (APAC workloads)
│   ├── Dubai Account(s)    (MEA workloads)
│   └── Amsterdam Account(s)(EU workloads)
├── DR OU
└── Sandbox OU
```
The Management Account sits at the root and hosts only Organizations, Control Tower and billing. The Control Tower Log Archive and Audit accounts are placed in the Security OU.

The 300+ accounts live mainly under Production (per region and per business domain, optionally with child OUs), with non-prod accounts either in a Non-Production child OU or tagged within the regional OUs.

## Account ownership
| Account | Owner | Purpose |
|---|---|---|
| Management | Cloud platform | Org, billing, Control Tower |
| Security | Security team | Logging, detective controls, incident response |
| Network | Network team | All shared network constructs |
| Shared Services | Platform team | CI/CD, identity, DNS, tooling |
| Regional prod | App teams | Workloads |
| DR | Platform and app teams | Standby and recovery |
| Sandbox | Developers | Experiments, cost-capped |

## Service Control Policies
| SCP | Applied to | Effect |
|---|---|---|
| Region restriction | Root | Deny actions outside approved regions (`ap-south-1`, `me-central-1`, `eu-central-1`, plus DR region and global services) |
| Protect network | All OUs except Infrastructure | Deny creation of TGW, Cloud WAN, DX, VPC peering, IGW (except approved), VPN |
| Protect security tooling | Root | Deny disabling CloudTrail, Config, GuardDuty, Security Hub |
| Deny root user | Workload OUs | Deny root credentials usage |
| Encryption | Production OU | Deny unencrypted EBS/S3/RDS |
| Sandbox limits | Sandbox OU | Deny large instance types, network constructs, DX |
| Block leaving org | Root | Deny `organizations:LeaveOrganization` |

SCPs are tested in a sandbox OU first and rolled out OU by OU. Terraform manages them; changes need two reviewers.

## Resource sharing
AWS RAM sharing is enabled org-wide. Network Account shares: IPAM pools, Route 53 Resolver rules, Cloud WAN core network (for attachment), and prefix lists. Shares are scoped to OUs, not individual accounts.

## Tagging policy
Mandatory tags: `CostCenter`, `Application`, `Environment`, `DataClass`, `Owner`, `Region-Domain`. Enforced via tag policies and SCP conditions on creation.
