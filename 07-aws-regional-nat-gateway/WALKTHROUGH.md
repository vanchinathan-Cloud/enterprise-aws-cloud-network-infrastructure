# Full Walkthrough — AWS Regional NAT Gateway

This is the detailed, console-click-by-console-click version of the build. See the main [README](./README.md) for the summarized version.

**Scenario:** A fully private application tier (no public IPs, no bastion host) that needs outbound internet access, accessed for testing via **EC2 Instance Connect Endpoint** rather than SSH from the internet, using a single **Regional NAT Gateway** across two AZs.

## 1. Create the VPC

- **VPC → Create VPC**
  - Name: `NAT-Test-VPC`
  - IPv4 CIDR: `10.10.0.0/16` (no IPv6)

## 2. Internet Gateway

- Create `Test-IG`, attach to `NAT-Test-VPC`.

## 3. Create subnets

| Subnet | AZ | CIDR | Purpose |
|---|---|---|---|
| `EC2-endpoint-Private` | `ap-south-1a` | `10.10.0.0/24` | Hosts the EC2 Instance Connect Endpoint |
| `app-private-1` | `ap-south-1a` | `10.10.1.0/24` | App tier |
| `app-private-2` | `ap-south-1b` | `10.10.2.0/24` | App tier (second AZ) |

## 4. Route table for the app subnets

- Create route table `app-private`, VPC `NAT-Test-VPC`
- Subnet associations → associate `app-private-1` and `app-private-2` only (not the endpoint subnet)

## 5. Create the EC2 Instance Connect Endpoint

This is what allows SSH access to fully private instances — no public IP, no bastion host, no inbound internet rule needed.

1. Security group `ec2-instance-connect-endpoint-sg` — allow outbound (default)
2. **VPC → Endpoints → Create endpoint**
   - Name: `ec2-instance-connect`
   - Type: **EC2 Instance Connect Endpoint**
   - VPC: `NAT-Test-VPC`
   - Security group: `ec2-instance-connect-endpoint-sg`
   - Subnet: `EC2-endpoint-Private`

## 6. Launch the app instances

- `app-1` — subnet `app-private-1`, security group `app-sg` (inbound SSH from source = the endpoint's security group `ec2-instance-connect-endpoint-sg`, not `0.0.0.0/0`)
- `app-2` — subnet `app-private-2`, reuse `app-sg`

## 7. Confirm the "before" state

Connect to `app-1` via **EC2 → Connect → EC2 Instance Connect → Connect using Private IP**.

Try `ping google.com` — **this fails**, because there's no outbound internet route yet.

## 8. Create the Regional NAT Gateway

- **VPC → NAT Gateway → Create NAT gateway**
  - Name: `Test RNAT`
  - Availability: **Regional – New**
  - VPC: `NAT-Test-VPC`
  - Connectivity type: **Public**
  - Elastic IP allocation: **Automatic**

## 9. Update the app route table

- `app-private` route table → Edit routes → Add: `0.0.0.0/0` → target the Regional NAT Gateway

## 10. Re-test

- Reconnect to `app-1` via EC2 Instance Connect Endpoint, `ping google.com` — now succeeds.
- Repeat on `app-2` to confirm the same NAT Gateway serves both AZs without any per-AZ NAT setup.

## 11. Clean up

Once testing is confirmed, **delete the EC2 instances and the NAT Gateway** — NAT Gateways bill hourly whether or not they're in active use, so tearing down lab resources promptly avoids ongoing cost.
