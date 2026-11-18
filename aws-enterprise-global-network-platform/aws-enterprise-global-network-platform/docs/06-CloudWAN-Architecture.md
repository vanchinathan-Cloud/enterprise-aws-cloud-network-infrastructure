# 06 - Cloud WAN Architecture

## Core network
One global network in the Network Account with three core network edges (CNEs):

| Edge | Region | ASN (assumed) |
|---|---|---|
| APAC | `ap-south-1` | 64512 |
| MEA | `me-central-1` | 64513 |
| EU | `eu-central-1` | 64514 |

Add the DR region as a fourth edge if it differs from these three. Inside-CIDR blocks for the edges come from the IPAM reserved pool.

## Segments
| Segment | Purpose | Isolated | Approval |
|---|---|---|---|
| `prod` | Production workloads | Yes | Required |
| `nonprod` | Dev, test, staging | Yes | Auto |
| `dr` | DR OU workloads | Yes | Required |
| `shared` | Shared services, DNS, CI | Reached only via inspection | Required |
| `security` | Log, scanning, tooling | Yes | Required |
| `onprem` | DX (via TGW), SD-WAN, data centres | Reached only via inspection | Auto (platform-owned attachments) |

Attachments are mapped to segments by tag (`segment=prod`). Workload accounts' attachments wait for acceptance in prod, dr, shared and security; the platform pipeline accepts them. The Terraform in `terraform/cloudwan.tf` is the source of truth for the policy.

## Policy outline
```json
{
  "version": "2021.12",
  "core-network-configuration": {
    "asn-ranges": ["64512-64520"],
    "edge-locations": [
      {"location": "ap-south-1"},
      {"location": "me-central-1"},
      {"location": "eu-central-1"}
    ]
  },
  "segments": [
    {"name": "prod",  "require-attachment-acceptance": true,  "isolate-attachments": false},
    {"name": "nonprod","require-attachment-acceptance": false, "isolate-attachments": false},
    {"name": "shared", "require-attachment-acceptance": true},
    {"name": "onprem", "require-attachment-acceptance": true}
  ],
  "attachment-policies": [
    {"rule-number": 100, "conditions": [{"type": "tag-value", "key": "segment", "operator": "equals", "value": "prod"}],
     "action": {"association-method": "tag", "tag-value-of-key": "segment"}}
  ]
}
```
The policy above is an outline; the full policy lives in `network-terraform` and is validated in CI before apply.

## Segment sharing and service insertion
- `prod`, `nonprod` share routes with `shared` through segment actions (`share`).
- Inter-segment traffic and internet egress use **network function groups** (service insertion) that send traffic through the Inspection VPC attachment in each region (doc 10).
- Segments reaching `onprem` also pass through inspection.

## Attachment types
| Type | Used for |
|---|---|
| VPC | Workload and inspection VPCs |
| Transit Gateway route table | Direct Connect integration (doc 08) |
| Site-to-Site VPN / Connect | SD-WAN integration at edges |

## SD-WAN integration
Cisco SD-WAN virtual routers (Catalyst 8000V) are deployed as Connect or VPN-terminating appliances at each edge, so airports and offices reach AWS through the nearest region with BGP route exchange. Prefix filters prevent route leaking between regions.

## Operations
- Policy changes go through PR, `terraform plan`, policy-version diff, approval, then apply.
- Use the policy change set's rollback capability if validation fails.
- CloudWatch network monitoring, Network Manager topology and event notifications feed the NOC.
