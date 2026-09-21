# 05 — Site-to-Site VPN Lab

![Architecture Diagram](./architecture-diagram.svg)

Full walkthrough: [WALKTHROUGH.md](./WALKTHROUGH.md)

## Overview
This lab builds a real IPsec Site-to-Site VPN between an AWS VPC and a simulated on-premises environment. Since a physical on-prem router isn't available, a second AWS VPC (in a different region, standing in as "the DC") runs an EC2 instance configured with Libreswan as the on-prem VPN endpoint.

**AWS side:** `AWS-VPC` (`10.0.0.0/16`) in Mumbai (`ap-south-1`)
**Simulated on-prem side:** `DC-VPC` (`192.168.0.0/16`) in N. Virginia (`us-east-1`), with a public EC2 instance running Libreswan as the VPN gateway

## Core Components

| Component | Purpose |
|---|---|
| **Customer Gateway (CGW)** | Represents the on-prem side — the VPN Server EC2's public IP and BGP ASN (`65000`, default) |
| **Virtual Private Gateway (VGW)** | The AWS-side termination point, attached to `AWS-VPC` |
| **Site-to-Site VPN Connection** | Static-routed IPsec tunnel(s) between the CGW and VGW — AWS provisions two tunnel endpoints for redundancy |
| **Static routing** | Route propagation via manually declared CIDRs (`192.168.0.0/16` on the AWS side) rather than BGP |
| **On-prem simulator** | EC2 instance running **Libreswan** in a second VPC (`DC-VPC`), acting as the on-prem VPN gateway |
| **Source/Destination Check** | Must be disabled on the on-prem VPN Server instance — without this, AWS drops any packet not addressed directly to/from the instance, which breaks its ability to route traffic on behalf of other instances |

## Build Steps

1. Create `AWS-VPC` (`10.0.0.0/16`) in `ap-south-1` with a private subnet and route table.
2. Launch a test EC2 instance (`EC2-A`) in the AWS private subnet.
3. Create `DC-VPC` (`192.168.0.0/16`) in `us-east-1` with a public subnet (with IGW) and a private subnet.
4. Launch the `VPN Server` EC2 instance in the DC public subnet (with a public IP) and a second test instance (`EC2-B`) in the DC private subnet.
5. Create a Virtual Private Gateway, attach it to `AWS-VPC`.
6. Create a Customer Gateway pointing at the VPN Server's public IP.
7. Create the Site-to-Site VPN Connection (static routing, prefix `192.168.0.0/16`), then download the generated configuration file.
8. Install Libreswan on the VPN Server and configure `/etc/ipsec.conf`, `/etc/ipsec.d/aws.conf`, and `/etc/ipsec.d/aws.secrets` using values from the downloaded config (see [WALKTHROUGH.md](./WALKTHROUGH.md) for exact fields).
9. Start the IPsec service and confirm at least one tunnel shows `UP` in the AWS console.
10. Add a static route in the AWS route table: `192.168.0.0/16` → Virtual Private Gateway.
11. **Disable Source/Destination Check** on the VPN Server instance.
12. Add a route in the DC private route table: `10.0.0.0/16` → target the VPN Server instance.
13. SSH from the VPN Server to `EC2-B`, then ping `EC2-A`'s private IP to confirm full end-to-end connectivity.

## Lessons Learned

- **The tunnel coming up ≠ traffic flowing.** Getting Tunnel status to `UP` in the console was only step one — ping still failed until the AWS-side route table had an explicit static route for the on-prem CIDR pointing at the VGW.
- **Source/Destination Check is the single easiest thing to forget, and it silently breaks everything.** The on-prem VPN Server needs to forward traffic on behalf of `EC2-B`, but AWS blocks that by default on any instance — disabling this check was the fix, and it wasn't obvious from the tunnel/route configuration alone that this was the missing piece.
- **The downloaded VPN configuration template needs manual edits for Libreswan**, not a direct copy-paste — an `auth=esp` line in the OpenSwan-vendor template needed to be removed, and the `phase2alg`/`ike` algorithm strings needed to match what AWS actually generated for the tunnel.
- **Routing through an EC2 instance (rather than a managed gateway) requires an explicit instance-target route** on the private-side route table (`10.0.0.0/16` → the VPN Server's instance ID) — this is a different route table pattern than pointing at an IGW/VGW/NAT Gateway.
- **The "on-prem" simulation only works one direction without extra routing.** AWS → DC private subnet worked once the AWS route table had the static route; DC → AWS also needed the VPN Server to be explicitly allowed to route (source/dest check) and the DC private route table to know to send AWS-bound traffic through the VPN Server.
- **Once you've completed this lab, delete the resources you created** — the Site-to-Site VPN Connection, Virtual Private Gateway, Customer Gateway, and all EC2 instances (VPN Server, EC2-A, EC2-B) in both VPCs — otherwise these will keep charging your AWS account every month.

## Validation Checklist

- [ ] Site-to-Site VPN Connection shows at least one tunnel `UP`
- [ ] AWS route table has a static route for the on-prem CIDR pointing at the VGW
- [ ] Source/Destination Check is disabled on the on-prem VPN Server instance
- [ ] DC private route table has a route for the AWS CIDR pointing at the VPN Server instance
- [ ] Ping from AWS-side private EC2 to DC-side private EC2 succeeds (or vice versa)
- [ ] `sudo systemctl status ipsec` on the VPN Server shows the service active
