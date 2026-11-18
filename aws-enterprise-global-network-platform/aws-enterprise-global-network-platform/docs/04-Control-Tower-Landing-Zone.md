# 04 - Control Tower Landing Zone

## Setup
- **Home region:** `ap-south-1` (Mumbai). Governed regions: `ap-south-1`, `me-central-1`, `eu-central-1`, and the DR region.
- Control Tower deployed in the Management Account; Log Archive and Audit accounts in the Security OU.
- KMS-encrypted central CloudTrail and Config aggregation; log bucket with object lock and 7-year retention.
- IAM Identity Center is the single workforce identity entry point, federated to the corporate IdP.

## Guardrails
| Type | Examples |
|---|---|
| Preventive (SCP) | Region deny, protect CloudTrail/Config, deny public S3, deny root user |
| Detective (Config) | Public subnets, unencrypted volumes, open security groups, VPC flow logs disabled |
| Proactive (CloudFormation hooks) | Block non-compliant resource creation |

Guardrail rollout: Sandbox, then Non-Prod, then Production, using OU-level enablement.

## Account Factory for Terraform (AFT)
Account vending uses AFT, driven by GitHub Actions.

```
Request (PR with account request file)
   -> Review and approve
   -> AFT creates account in target OU
   -> Global customizations: baseline IAM, logging, security tooling, tags
   -> Account customizations: VPC from IPAM pool, Cloud WAN attachment, Resolver rule association
   -> Notification and handoff
```

### Network baseline applied to every account
1. VPC created from the correct IPAM pool (doc 05).
2. VPC attached to the proper Cloud WAN segment via tag (doc 06).
3. Route 53 Resolver rules and PHZ associations (doc 09).
4. VPC Flow Logs to the Security account.
5. Default security group closed; no IGW unless approved.

## Customization pipeline
| Repo | Content |
|---|---|
| `landing-zone-terraform` | Control Tower, AFT, SCPs, baselines |
| `network-terraform` | Cloud WAN, TGW, DX, IPAM, inspection |

## Drift management
Control Tower drift checks run weekly and after major changes. Drift tickets go to the platform team with a 5-day fix SLA. Never alter Control Tower-managed resources manually.

## Decommissioning
Account closure workflow: remove attachments, release IPAM allocations, remove DNS associations, move to a Suspended OU for 90 days, then close.
