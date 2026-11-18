# 13 - Operations Runbook

## Roles
| Team | Responsibility |
|---|---|
| NOC (24x7) | Monitoring, first response |
| Network engineering | DX, Cloud WAN, TGW, SD-WAN, inspection |
| Platform | Control Tower, AFT, pipelines |
| SOC | Security alerts and incidents |

## Standard changes (via pipeline)
1. Open a PR in `network-terraform` or `landing-zone-terraform`.
2. GitHub Actions runs `fmt`, `validate`, `tflint`, `checkov`, and `terraform plan`.
3. Reviewers approve (two for Cloud WAN policy, SCPs and firewall rules).
4. Merge triggers apply in the target environment, with a manual approval gate for prod.
5. Post-change verification (below).

## Procedures
### Onboard a new account
1. Submit account request PR (name, OU, environment, region, owner, cost centre).
2. AFT vends the account and applies baselines; IPAM allocates the VPC CIDR.
3. Verify: VPC attached to the correct segment, Resolver rules associated, flow logs on, reachability test passes.

### Add or change a Cloud WAN segment or policy
Edit the policy in Terraform, review the policy diff, apply, then confirm in Network Manager that the change set executed and attachments are in the expected segments. Roll back to the previous version if routes are wrong.

### Direct Connect failover test
Shut a connection on the customer side during a change window, confirm BGP converges, traffic shifts, and alarms fire, then restore. Record times.

### Firewall rule change
PR with rule group change, plan shows the rule diff, approve, apply. Emergency deny rules follow the fast-track path with retrospective review.

### Emergency bypass of inspection
Only with incident-commander approval: change the segment action in a time-boxed PR, set an automatic revert, notify SOC. Never bypass manually in the console.

## Alerts (examples)
| Alarm | Threshold | Action |
|---|---|---|
| DX connection down | State = 0 | Page network on-call |
| BGP session down | > 1 min | Page network on-call |
| DX utilisation | > 70% | Plan capacity |
| Firewall dropped packets spike | Anomaly | SOC triage |
| IPAM pool > 80% | Pool utilisation | Plan pool expansion |
| Resolver endpoint unhealthy | Any | Network on-call |

## Troubleshooting flow
1. Define source, destination, protocol, port.
2. Check Network Manager route analyzer and Reachability Analyzer.
3. Check segment policy and attachment state.
4. Check Network Firewall logs for drops.
5. Check security groups, NACLs, DNS resolution.
6. Check on-premises side (BGP, SD-WAN policy).

## Reporting
Weekly health report (availability, incidents, capacity), monthly change and drift report, quarterly DR test results.
