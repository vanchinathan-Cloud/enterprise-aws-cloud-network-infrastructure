# Terraform

Deploys into the **Network Account**.

| File | Purpose |
|---|---|
| `ipam.tf` | IPAM, top pool, environment pools, per-region pools, reserved on-premises/VPN ranges |
| `cloudwan.tf` | Global network, core network, segments, inspection service insertion, DX gateway |
| `hubs.tf` | Calls `modules/regional-hub` for Mumbai, Dubai, EU (Frankfurt) |
| `modules/regional-hub` | Inspection VPC, Network Firewall, optional GWLB, DNS hub VPC and Resolver, regional TGW, DX association, RAM shares |

## Use

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # edit values
cp backend.hcl.example backend.hcl             # edit state bucket
terraform init -backend-config=backend.hcl
terraform validate
terraform plan
```

Before applying: enable `me-central-1` in the account (opt-in region), create the S3 state bucket and lock table, and confirm the DX connections and transit VIFs exist (they are ordered with the DX provider and attached to `aws_dx_gateway.this`).

## Things to check on first plan

- The Cloud WAN policy uses `send-via` / `send-to` with a network function group. Confirm the behaviour in a sandbox core network before production.
- TGW to Cloud WAN route-table attachment and policy-table steps in `tgw.tf` have several dependencies; expect to adjust ordering.
- Availability zone names (`a`, `b`) are per-account; replace with names that exist in your account.
- Network Firewall logs go to CloudWatch in this account. Ship them to the Security account for the final design.
- Workload VPC attachments are created by AFT, not here: tag them `segment=<name>` and accept them with `aws_networkmanager_attachment_accepter`.
