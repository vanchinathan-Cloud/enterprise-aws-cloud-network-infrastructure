# 07 — AWS Regional NAT Gateway

![Architecture Diagram](./architecture-diagram.svg)

## Overview
Regional NAT Gateway is a newer availability mode for AWS NAT Gateway (announced late 2025) that removes the traditional "one NAT Gateway per AZ" design entirely. Instead of provisioning a zonal NAT Gateway in a public subnet in every Availability Zone, you create a single NAT Gateway scoped to the whole VPC/region. AWS automatically expands it to cover new AZs as workloads appear there, and contracts it when they're removed — no public subnets, no per-AZ route tables, and no manual scaling required.

This sits alongside the traditional Zonal NAT Gateway as a second, simpler option for the same underlying problem: giving private subnets outbound internet access.

Key characteristics:
- Works at VPC level and spans across multiple Availability Zones
- Automatically expands into newer AZs as you deploy your workloads
- Optionally can choose manual mode to configure AZs for the Regional NAT Gateway
- Maintains zonal affinity (saves inter-AZ data transfer charge)
- No need to have public subnets for the Regional NAT Gateway
- Comes with its own route table

Full walkthrough: [WALKTHROUGH.md](./WALKTHROUGH.md)

This lab builds a fully private application tier — no public IPs, no bastion host — using **EC2 Instance Connect Endpoint** for SSH access, and a single **Regional NAT Gateway** for outbound internet across two AZs.

### Regional vs. Zonal NAT Gateway

| | Zonal NAT Gateway (traditional) | Regional NAT Gateway (new) |
|---|---|---|
| **Scope** | One NAT Gateway per AZ, tied to a specific public subnet | One NAT Gateway for the whole VPC, not tied to any subnet |
| **Public subnet required?** | Yes, one per AZ | No — public subnets aren't needed at all |
| **HA across AZs** | You design it yourself (one NAT GW + route table per AZ) | Built-in — AWS auto-expands/contracts across AZs as ENIs appear/disappear |
| **Route table** | You manage a separate private route table per AZ | Single route entry works across all AZs; AWS creates and manages the NAT's own route table |
| **Cross-AZ NAT data charges** | Possible if subnets are misrouted to a NAT Gateway in another AZ | Eliminated — traffic is handled without crossing AZs for NAT processing |
| **New AZ onboarding** | Manually create a new NAT Gateway + EIP + route table + associations | Automatic — can take up to ~60 minutes (typically 15–20) to expand once a resource appears in a new AZ |
| **Centralized egress via Transit Gateway** | Fully supported (standard pattern) | Not currently supported — the Regional NAT Gateway's route table is AWS-managed and can't be customized to redirect return traffic through a TGW |
| **IP address control** | Per-AZ EIP assignment (manual) | Automatic mode (AWS manages IPs/expansion, recommended) or Manual mode (you manage IPs and AZ coverage yourself) |

## Core Components

| Component | Purpose |
|---|---|
| **NAT Gateway (Availability mode = Regional)** | The single, VPC-wide NAT resource — no subnet is specified at creation. |
| **Elastic IP(s)** | Still required for translation; in Automatic mode AWS manages allocation (optionally from an IPAM pool), in Manual mode you assign EIPs per AZ yourself via `associate-nat-gateway-address`. |
| **AWS-managed Route Table ("Edge Association")** | Automatically created for the Regional NAT Gateway with a default route to the Internet Gateway and a local route for the VPC CIDR. Limited customization — you can add routes for middlebox return traffic, but not for redirecting to a Transit Gateway. |
| **VPC-level route entry** | Private subnets need just one route (`0.0.0.0/0` → the Regional NAT Gateway ID) — the same entry works for every AZ, unlike zonal NAT where each AZ needs its own route table. |
| **VPC IPAM Policy (optional)** | Lets you centrally define which IP pool (Amazon-provided or BYOIP) the Regional NAT Gateway draws its addresses from, useful at scale for partner IP allowlisting via managed prefix lists. |
| **EC2 Instance Connect Endpoint** | Lets you SSH into fully private instances (no public IP) directly from the console, without a bastion host or any inbound internet rule — used in this lab to reach and test the private app instances. |

## Build Steps

1. **Create the VPC and subnets** — one subnet for an EC2 Instance Connect Endpoint, and app subnets in 2+ AZs for the private workloads.
2. **Create the EC2 Instance Connect Endpoint** in its dedicated subnet, with a security group allowing outbound only — this is what enables SSH to fully private instances with no bastion host.
3. **Launch app instances** in the private app subnets, with security groups allowing SSH only from the Instance Connect Endpoint's security group (never `0.0.0.0/0`).
4. **Confirm the "before" state** — connect via EC2 Instance Connect Endpoint and verify outbound internet (e.g., `ping google.com`) fails, since there's no route yet.
5. **Create the NAT Gateway with Availability mode = Regional** — Public connectivity, Automatic Elastic IP allocation.
6. **Add the route** in the app subnets' route table (not the endpoint subnet's): `0.0.0.0/0` → the Regional NAT Gateway.
7. **Re-test** from each app instance — outbound internet access should now work, using the same NAT Gateway for both AZs with no per-AZ setup.
8. **Clean up** — delete the test EC2 instances and the NAT Gateway once validated, since NAT Gateways bill hourly.

### When to Use Regional vs. Zonal
- **Use Regional NAT Gateway** for most new VPC designs — simpler routing, automatic HA, no public subnet requirement, avoids cross-AZ NAT charges.
- **Stick with Zonal (per-AZ) NAT Gateways** if you need centralized egress through a Transit Gateway hub VPC (current limitation of Regional NAT), or fine-grained per-AZ routing control (e.g., routing specific AZ traffic through different middleboxes).

## Lessons Learned

**From this build:**
- **Ping fails until both the NAT Gateway exists *and* the route table points to it** — creating the NAT Gateway alone didn't get outbound traffic flowing; the app subnet route table needed an explicit `0.0.0.0/0` → NAT Gateway route added afterward.
- **EC2 Instance Connect Endpoint removes the need for a bastion host or public IPs entirely** — both app instances stayed fully private (no public IP, no `0.0.0.0/0` inbound SSH rule) and were still reachable for testing directly from the console.
- **The endpoint subnet and the app subnets need different route table associations** — the `EC2-endpoint-Private` subnet was deliberately left off the `app-private` route table association; only the two app subnets needed the NAT route.
- **NAT Gateways bill hourly regardless of use** — after confirming ping worked from both AZs, the right move was to delete the NAT Gateway (and test instances) immediately rather than leave it running idle.

**Also worth knowing (documented AWS behavior, not independently re-verified in this lab):**
- AZ expansion for a Regional NAT Gateway is not instant — AWS documents this as typically 15–20 minutes, up to ~60 minutes, when a resource first appears in a new AZ.
- Regional NAT Gateway is not currently compatible with centralized egress through a Transit Gateway hub — the AWS-managed route table can't be redirected to a TGW. For that pattern (like Module 04's hub-and-spoke), the traditional zonal NAT Gateway is still the documented approach.
- Manual mode shifts EIP and AZ-coverage responsibility to you — Automatic mode is what AWS recommends for most cases.

## Validation Checklist

- [ ] EC2 Instance Connect Endpoint created and reachable — no bastion host, no public IPs on app instances
- [ ] Outbound internet fails from app instances *before* the NAT route is added (confirms the "before" state is real, not assumed)
- [ ] NAT Gateway created with Availability mode = Regional, Elastic IP allocated
- [ ] App subnet route table has `0.0.0.0/0` → Regional NAT Gateway (endpoint subnet route table left unchanged)
- [ ] Outbound internet access works from app instances in both AZs using the same NAT Gateway
- [ ] Test resources (EC2 instances, NAT Gateway) deleted after validation to avoid ongoing cost
