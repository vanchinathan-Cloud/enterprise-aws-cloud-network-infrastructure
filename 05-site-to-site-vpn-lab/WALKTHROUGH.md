# Full Walkthrough — Site-to-Site VPN Lab

This is the detailed, console-click-by-console-click version of the build. See the main [README](./README.md) for the summarized version.

**Scenario:** AWS VPC (Mumbai — `ap-south-1`) connected via IPsec Site-to-Site VPN to a simulated on-premises "DC" environment (N. Virginia — `us-east-1`), with the on-prem side running Libreswan on an EC2 instance.

## 1. Create the AWS-side VPC (Mumbai)

1. **VPC → Create VPC**
   - Name: `AWS-VPC`
   - IPv4 CIDR: `10.0.0.0/16`
2. **Subnets → Create subnet**
   - VPC: `AWS-VPC`
   - Subnet name: `AWS-Private-subnet`
   - AZ: `ap-south-1a`
   - IPv4 CIDR: `10.0.0.0/24`
3. **Route Tables → Create route table**
   - Name: `AWS-Private-RT`, VPC: `AWS-VPC`
   - Subnet associations → associate `AWS-Private-subnet`
4. **Launch an EC2 instance** (`EC2-A`) in `AWS-Private-subnet`
   - Security group `AWS-app-sg`: allow all ICMPv4 from custom source `192.168.0.0/16` (the DC VPC CIDR)

## 2. Create the simulated on-prem "DC" VPC (N. Virginia)

1. **VPC → Create VPC**
   - Name: `DC-VPC`
   - IPv4 CIDR: `192.168.0.0/16`
2. **Internet Gateway** — create `DC-IGW`, attach to `DC-VPC` (needed so the VPN server has internet reachability)
3. **Subnets**
   - `DC-Public-Subnet` — AZ `us-east-1a`, CIDR `192.168.0.0/24`
   - `DC-Private-Subnet` — AZ `us-east-1a`, CIDR `192.168.100.0/24`
4. **Route tables**
   - `DC-Public-RT` → route `0.0.0.0/0` → `DC-IGW`, associate with `DC-Public-Subnet`
   - `DC-Private-RT` → associate with `DC-Private-Subnet` (no internet route needed yet)
5. **Launch EC2 instances**
   - `VPN Server` in `DC-Public-Subnet`, auto-assign public IP enabled, security group `vpn-server-sg` allowing all ICMPv4 from anywhere
   - `EC2-B` in `DC-Private-Subnet`, security group allowing SSH + ICMPv4 from `192.168.0.0/16` and `10.0.0.0/16`

## 3. Build the IPsec VPN connection

1. **Create a Virtual Private Gateway** (AWS Mumbai side)
   - Name: `aws-network-vpg` → Attach to `AWS-VPC`
2. **Create a Customer Gateway**
   - Name: `dc-network-cgw`
   - ASN: `65000` (default)
   - IP address: the VPN Server's public IP
3. **Create the Site-to-Site VPN Connection**
   - Name: `aws-dc-vpn`
   - Target: Virtual Private Gateway → `aws-network-vpg`
   - Customer Gateway: `dc-network-cgw`
   - Routing: **Static**, prefix `192.168.0.0/16`
4. **Download the configuration** (Vendor: OpenSwan template — works for Libreswan with minor edits) as a text file.

## 4. Configure Libreswan on the VPN Server (on-prem side)

SSH into the VPN Server EC2 instance (Amazon Linux 2023):

```bash
sudo yum install libreswan -y
```

Edit `/etc/sysctl.conf`, add:
```
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.accept_source_route = 0
```
Apply with `sudo sysctl -p`.

Create `/etc/ipsec.d/aws.conf`, pasting in the `conn Tunnel1` block from the downloaded config. Key fields to check/update:

```
authby=secret
auto=start
left=%defaultroute
leftid=<VPN Server public IP>
right=<one of the two AWS VGW tunnel public IPs>
type=tunnel
ikelifetime=8h
keylife=1h
phase2alg=aes128-sha256      # update to match the downloaded config
ike=aes128-sha256;modp2048   # update to match the downloaded config
keyingtries=%forever
keyexchange=ike
leftsubnet=192.168.0.0/16    # DC-VPC CIDR
rightsubnet=10.0.0.0/16      # AWS-VPC CIDR
dpddelay=10
dpdtimeout=30
dpdaction=restart_by_peer
```

> Note: the downloaded template includes an `auth=esp` line that needs to be removed for Libreswan.

Create `/etc/ipsec.d/aws.secrets` with the pre-shared key from the downloaded config file.

Start the tunnel:
```bash
sudo systemctl start ipsec.service
sudo systemctl status ipsec.service
```

## 5. Wire up routing on both sides

**AWS side** — the tunnel comes up, but ping doesn't work yet because there's no route:
- Go to `AWS-Private-RT` → Routes → Edit → Add route: `192.168.0.0/16` → target: the Virtual Private Gateway

**Verify:** in the console, **Site-to-Site VPN Connections → Tunnel details** — at least one tunnel should show `UP`.

**DC side** — the VPN Server needs to route traffic *through* itself to the private EC2-B instance, which requires two things:
1. **Disable Source/Destination Check** on the VPN Server instance (EC2 → Actions → Networking → Change source/destination check → Stop). Without this, AWS drops any packet whose source/destination doesn't match the instance's own IP — which breaks routing-through-an-instance entirely.
2. **Add a route** in `DC-Private-RT`: `10.0.0.0/16` → target: the VPN Server instance (not an IGW/VGW — a specific EC2 instance as the routing target)

## 6. Test end-to-end

1. From the VPN Server (public EC2), copy the private key for EC2-B onto the box (`vi key.pem`, paste, then `chmod 400 key.pem`)
2. SSH from the VPN Server to EC2-B's private IP: `ssh -i key.pem <EC2-B private IP>`
3. From EC2-B, ping the AWS-side private EC2-A's IP — this should now succeed, confirming the full on-prem → tunnel → AWS path works.
