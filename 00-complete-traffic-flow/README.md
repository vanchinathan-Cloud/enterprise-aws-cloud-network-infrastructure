# Module 00: Complete AWS Traffic Flow — Request Journey Through All Layers

## 🎯 Overview

A production request traveling to your application doesn't take a direct path. It passes through **11 networking layers**, each performing critical functions: DNS resolution, global caching, security filtering, load balancing, routing, access control, and private service connectivity.

### Why This Matters

When something breaks (application unreachable, database timeout, slow response), you won't know which layer to investigate without understanding the complete flow. A methodical troubleshooting approach—tracing the request path step by step—reveals the issue 90% of the time.

**This Module**: Maps the complete journey of a production request, showing what happens at each layer, common failure points, and how to debug the entire chain.

### How to Use This Module

1. **Read first** before any other module (00-10) to understand the complete picture
2. **Reference often** when debugging production issues
3. **Use troubleshooting scenarios** as a template for similar problems
4. **Run validation scripts** to confirm all layers are working

---

## 🔄 The Complete Traffic Flow (11 Layers)

### Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        INTERNET (User)                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    1. DNS Resolution
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │      Route 53 (DNS Query)              │
        │  - Resolves example.com to IP          │
        │  - Health checks active endpoints      │
        │  - Returns endpoint IP (203.0.113.1)   │
        └────────────────────┬───────────────────┘
                             │
                    2. Global Distribution
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  CloudFront (CDN) + WAF                │
        │  - Checks cache hit (images, static)   │
        │  - WAF inspects request                │
        │  - Blocks malicious traffic            │
        │  - Routes to origin (ALB)              │
        └────────────────────┬───────────────────┘
                             │
                    3. TLS Termination
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  Application Load Balancer (ALB)       │
        │  - Accepts HTTPS connection            │
        │  - Terminates TLS/SSL                  │
        │  - Checks target health                │
        │  - Routes to healthy targets           │
        └────────────────────┬───────────────────┘
                             │
              4. VPC Boundary & Routing
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  Virtual Private Cloud (VPC)           │
        │  - Public Subnet (ALB lives here)      │
        │  - Route Table: 0.0.0.0/0 → IGW       │
        │  - Determines if traffic is local      │
        └────────────────────┬───────────────────┘
                             │
          5. First Security Layer (ALB SG)
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  Security Group (ALB)                  │
        │  - Stateful firewall                   │
        │  - Allows: TCP 80, 443 from 0.0.0.0/0 │
        │  - Response auto-allowed               │
        │  - Blocks other protocols              │
        └────────────────────┬───────────────────┘
                             │
            6. Forward to App Servers
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  Target Group (Private Subnet)         │
        │  - EC2/ECS/EKS instances (port 8080)   │
        │  - ALB performs health checks (30s)    │
        │  - Load balances across targets        │
        │  - Round-robin or least outstanding    │
        └────────────────────┬───────────────────┘
                             │
          7. Second Security Layer (App SG)
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  App Server Security Group             │
        │  - Stateful firewall (per instance)    │
        │  - Allows: TCP 8080 from ALB SG only   │
        │  - Blocks SSH from internet            │
        │  - Responds to incoming traffic        │
        └────────────────────┬───────────────────┘
                             │
        8. Application Processing
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  Application Server (EKS Pod/ECS)      │
        │  - Receives HTTP request on :8080      │
        │  - Processes business logic            │
        │  - Generates response                  │
        │  - May call external services          │
        └────────────────────┬───────────────────┘
                             │
        9. Database Layer Access
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  RDS Database (Private Subnet)         │
        │  - App initiates connection :3306      │
        │  - Encrypted tunnel (mutual TLS)       │
        │  - Returns query results               │
        │  - Auto-scales read replicas           │
        └────────────────────┬───────────────────┘
                             │
       10. Egress Control (NAT/Endpoints)
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  NAT Gateway / VPC Endpoints           │
        │  - App calls external API              │
        │  - NAT translates private IP           │
        │  - Appears as public IP (203.0.113.2)  │
        │  - Response returns through NAT        │
        └────────────────────┬───────────────────┘
                             │
        11. Response Path (Reverse Flow)
                             │
        Response travels back through:
        - App → ALB → CloudFront → User
        - Data cached in CloudFront
        - Response logged in ALB
        - Metrics sent to CloudWatch
                             │
                             ▼
        ┌────────────────────────────────────────┐
        │  User Receives Response                │
        │  - 200 OK, content delivered           │
        │  - Cache headers determine reuse       │
        │  - Browser caches as configured        │
        └────────────────────────────────────────┘
```

### Layer Reference Table

| Layer | Component | Purpose | Failure Impact |
|-------|-----------|---------|-----------------|
| 1 | Route 53 | DNS resolution | Domain unreachable |
| 2 | CloudFront + WAF | CDN + security filtering | Slow/blocked access |
| 3 | ALB | Load balancing + TLS termination | Requests fail |
| 4 | VPC + Route Tables | Network routing | Traffic lost |
| 5 | ALB Security Group | Inbound access control | Connections refused |
| 6 | Target Group | Distribution to app servers | No targets available |
| 7 | App Security Group | Application firewall | App unreachable |
| 8 | Application | Business logic | Errors/timeouts |
| 9 | RDS Database | Data storage | Query failures |
| 10 | NAT Gateway | Egress control | External access blocked |
| 11 | Response Path | Return to user | Slow response |

---

## 🔧 Core Components (Quick Reference)

### Networking Components

| Component | Purpose | Key Points |
|-----------|---------|-----------|
| **CIDR Block** | IP address range | VPC: 10.0.0.0/16, Subnet: 10.0.1.0/24 |
| **Subnet** | IP range in single AZ | Public (IGW) or Private (NAT) |
| **Internet Gateway (IGW)** | VPC ↔ Internet | One per VPC, allows bidirectional traffic |
| **Route Table** | Traffic direction rules | Determines path based on destination IP |
| **NAT Gateway** | Egress control | Private instances → Internet (outbound only) |
| **VPC Endpoints** | Private AWS access | S3, DynamoDB, and other services (no IGW/NAT needed) |

### Security Components

| Component | Purpose | Key Points |
|-----------|---------|-----------|
| **Security Group** | Stateful firewall | Instance-level, allows return traffic automatically |
| **Network ACL (NACL)** | Stateless firewall | Subnet-level, must allow ephemeral ports (1024-65535) |
| **Elastic IP (EIP)** | Static public IP | For NAT Gateways or EC2 instances |

### Application Components

| Component | Purpose | Key Points |
|-----------|---------|-----------|
| **ALB** | Load balancing | Distributes traffic, health checks, TLS termination |
| **Target Group** | Service endpoints | EC2, ECS, Lambda, or IP-based targets |
| **RDS** | Managed database | MySQL, PostgreSQL, Aurora, etc. |
| **VPC Flow Logs** | Traffic debugging | Capture all traffic in/out of ENIs (troubleshooting tool) |

---

## 🛠️ Understanding Request Flow — Deep Dive

### Step-by-Step Request Journey

#### **Step 1: DNS Lookup (Route 53)**
```
User's browser resolves domain
nslookup app.example.com
# Returns: 203.0.113.1 (CloudFront edge location)

Behind the scenes:
1. Route 53 receives DNS query
2. Checks health of registered endpoints
3. If primary unhealthy → routes to secondary
4. Returns endpoint IP
```

**Common Issues**:
- ❌ Domain name not registered
- ❌ Route 53 hosted zone not found
- ❌ Health check failing (primary down)
- ❌ Nameservers not updated at registrar

**Test**: `nslookup app.example.com` or `Resolve-DnsName app.example.com` (PowerShell)

---

#### **Step 2: Connect to CloudFront Edge (CDN + WAF)**
```
Browser connects to CloudFront edge (nearest location)
Example: User in London → CloudFront London edge

curl -I https://app.example.com/api/data

CloudFront checks:
1. Is /api/data cached? → Cache key: /api/data (query strings, cookies)
2. Run WAF rules:
   - Rate limiting: < 2000 requests/5 min? ✓
   - SQL injection patterns? ✓ Clean
   - Geo-blocking: Allowed country? ✓
3. Origin unreachable? Use stale cache if available
```

**Common Issues**:
- ❌ WAF rule too strict (blocks legitimate traffic)
- ❌ CloudFront origin not responding
- ❌ SSL certificate expired
- ❌ Cache policy prevents required headers

**Test**: `curl -I https://app.example.com -v` (check X-Cache header)

---

#### **Step 3: Forward to ALB (Application Load Balancer)**
```
CloudFront forwards request to origin (ALB)
Request includes X-Forwarded-For header (real client IP)

GET /api/data HTTP/1.1
Host: my-alb-123456789.us-east-1.elb.amazonaws.com
X-Forwarded-For: 203.0.113.50 (real user IP)
X-Forwarded-Proto: https

ALB receives request:
1. Check HTTPS listener (port 443) → configured ✓
2. Run listener rules:
   - If Host: api.example.com → API target group ✓
   - If Path: /api/* → API target group ✓
3. Select target group → forward to healthy targets
```

**Common Issues**:
- ❌ ALB security group blocks port 443
- ❌ Listener rules don't match (wrong target group)
- ❌ No targets registered or all unhealthy
- ❌ SSL certificate missing/invalid
- ❌ Target group health check path wrong

**Test**: `curl https://alb-dns.elb.amazonaws.com`

---

#### **Step 4: VPC Routing (Network Layer)**
```
Request enters VPC (public subnet)
Route table: Which direction?

Route Table (Public Subnets):
├── 10.0.0.0/16 (local) → Local (stay in VPC)
├── 0.0.0.0/0 → igw-12345 (to internet)

Decision: Destination = 10.0.2.1 (app server)
→ 10.0.0.0/16 matches → LOCAL route
→ Stay in VPC, don't leave through IGW
```

**Common Issues**:
- ❌ Route table not associated with subnet
- ❌ Wrong route (points to wrong target)
- ❌ No route to destination (packet dropped)
- ❌ Route via wrong NAT Gateway

---

#### **Step 5: Security Groups (Firewall Layer)**
```
ALB Security Group (sg-alb):
├── Inbound Rules:
│   ├── TCP 80 from 0.0.0.0/0 ✓ Allowed
│   ├── TCP 443 from 0.0.0.0/0 ✓ Allowed
│   └── Other protocols → Blocked
├── Outbound Rules:
│   ├── All traffic to app servers → Allowed
│   └── (Stateful: response auto-allowed)
└── Result: ✓ ALLOW

App Server Security Group (sg-app):
├── Inbound Rules:
│   ├── TCP 8080 from sg-alb ✓ Allowed
│   └── Other → Blocked
├── Outbound Rules:
│   ├── TCP 3306 to sg-rds (MySQL) ✓
│   ├── TCP 443 to 0.0.0.0/0 (APIs) ✓
│   └── Other → Blocked (restrictive)
```

**Key Concept**: Security groups are STATEFUL
- Inbound traffic allowed → Outbound response auto-allowed
- No need to add reverse rule for responses

---

#### **Step 6: Application Processing (Layer 8)**
```
App server receives HTTP request on :8080

Application Logic:
1. Receive GET /api/data
2. Check authentication/authorization
3. Query database for data
4. Call external API (if needed)
5. Format response
6. Send 200 OK + JSON

Example Python Flask:
@app.route('/api/data')
def get_data():
    data = db.query("SELECT * FROM users")
    response = requests.get('https://external-api.com/data')
    return jsonify(data)
```

**Common Issues**:
- ❌ Application error (500)
- ❌ Database unreachable (timeout)
- ❌ External API unreachable
- ❌ Authentication failing
- ❌ Permissions issue (403)

---

#### **Step 7: Database Access (Layer 9)**
```
App server (10.0.2.10) connects to RDS

Connection Attempt:
1. Destination: rds-prod.us-east-1.rds.amazonaws.com:3306
2. Resolve DNS to private IP (10.0.3.10)
3. Check RDS Security Group:

   RDS Security Group (sg-rds):
   ├── Inbound Rules:
   │   ├── TCP 3306 from sg-app ✓ Allowed
   │   └── Other → Blocked
   ├── Outbound Rules: None
   └── Result: ✓ ALLOW

4. Establish encrypted connection (mutual TLS)
5. Authenticate with username/password
6. Execute SQL query
7. Return results to application
```

**Common Issues**:
- ❌ RDS security group doesn't allow app source
- ❌ RDS not in right subnet group
- ❌ Database credentials wrong
- ❌ Database not running/available
- ❌ Network ACL blocks 3306

---

#### **Step 8: Egress Control (Layer 10)**
```
App calls external API
curl https://external-api.com/data

Request Path:
App server (10.0.2.10, private subnet)
→ NAT Gateway (public subnet, 203.0.113.2)
→ Internet
→ external-api.com

NAT Translation:
Source IP: 10.0.2.10 → 203.0.113.2
Destination: external-api.com

Response:
Source IP: external-api.com
Destination: 203.0.113.2 → NAT translates back to 10.0.2.10
```

**Common Issues**:
- ❌ No NAT Gateway (private subnet can't reach internet)
- ❌ NAT Gateway not in route table
- ❌ NAT Gateway unhealthy/down
- ❌ Security group blocks outbound
- ❌ VPC endpoint needed instead (for AWS services)

---

#### **Step 9: Response Path (Reverse Flow)**
```
Response travels back:
App Server → ALB → CloudFront → User

1. App sends 200 OK + JSON response
2. ALB receives response
3. ALB adds headers (X-Amzn-Trace-Id, etc.)
4. CloudFront receives response
5. Check cache headers (Cache-Control, Expires)
6. Cache response (if appropriate)
7. Return to user
8. Browser renders response

Total flow completes in 200-500ms (depending on caching and database queries)
```

---

## ⚠️ Lessons Learned — Real Troubleshooting Scenarios

### Scenario 1: "Connection Timeout" — Users Can't Reach Application

**Error**: `Connection timeout` when visiting `https://app.example.com`

**Debugging Path**:

```bash
# Step 1: DNS works?
nslookup app.example.com
# Output: 203.0.113.1 ✓

# Step 2: CloudFront reachable?
curl -I https://203.0.113.1
# Output: Timeout ✗

# Step 3: Is CloudFront origin (ALB) alive?
aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN
# Status: active, State: active ✓

# Step 4: ALB targets healthy?
aws elbv2 describe-target-health --target-group-arn $TG_ARN
# Status: Unhealthy ✗ ← FOUND IT!

# Step 5: Why unhealthy?
aws ec2 describe-security-groups --group-ids sg-app
# TCP 8080 from sg-alb: MISSING ✗

# Fix:
aws ec2 authorize-security-group-ingress \
  --group-id sg-app \
  --protocol tcp \
  --port 8080 \
  --source-group sg-alb

# Verify:
aws elbv2 describe-target-health --target-group-arn $TG_ARN
# Status: Healthy ✓

# Test:
curl https://app.example.com
# Success!
```

**Root Cause**: App security group missing inbound rule for ALB.

**Note**: Targets may appear Healthy for up to 30 seconds after a rule change. ALB performs health checks every 10 seconds by default (3 failures = unhealthy). Allow time for the health check to cycle.

---

### Scenario 2: "Database Connection Timeout" — App Can't Query Database

**Error**: Application logs show `ERROR: timeout waiting for connection to database`

**Debugging Path**:

```bash
# Step 1: Is RDS running?
aws rds describe-db-instances --db-instance-identifier prod-db
# DBInstanceStatus: available ✓

# Step 2: Can app server reach RDS port?
# SSH to app server and test:
nc -zv rds-prod.us-east-1.rds.amazonaws.com 3306
# Connection refused ✗

# Step 3: Check RDS security group:
aws ec2 describe-security-groups --group-ids sg-rds
# TCP 3306 from sg-app: MISSING ✗

# Fix:
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 3306 \
  --source-group sg-app

# Test again:
nc -zv rds-prod.us-east-1.rds.amazonaws.com 3306
# Connection successful ✓

# Check app logs:
tail -f /var/log/app.log
# Database queries now succeeding ✓
```

**Root Cause**: RDS security group didn't allow app server source.

**Alternative**: If the app is in a different subnet/SG, check:
- RDS is in the correct subnet group (multi-AZ)
- App has correct username/password
- Database encryption settings (KMS key permissions)

---

### Scenario 3: "High Latency" — Requests Taking 5+ Seconds

**Observation**: Response time degraded from 200ms to 5000ms+

**Debugging Path**:

```bash
# Step 1: Which layer is slow?
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name OriginLatency \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average

# OriginLatency: 4500ms (ALB → CloudFront) ✗ TOO HIGH

# Step 2: Check ALB response time
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average

# TargetResponseTime: 4200ms (Target → ALB) ✗ TOO HIGH

# Step 3: Which target is slow?
# SSH to instance:
time curl http://localhost:8080/health
# Real  0m4.215s ✗ App is slow

# Step 4: Is app hitting database?
# Check slow query log:
SELECT DISTINCT query, time
FROM slow_log
ORDER BY time DESC
LIMIT 10;

# Found: Query taking 4 seconds ✗

# Step 5: Add database index:
CREATE INDEX idx_user_id ON users(user_id);

# Test again:
time curl http://localhost:8080/api/data
# Real  0m0.150s ✓ Fast again

# Verify metrics:
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-02T00:00:00Z \
  --end-time 2024-01-03T00:00:00Z \
  --period 300 \
  --statistics Average

# TargetResponseTime: 150ms ✓ Restored to normal
```

**Root Cause**: Slow database query (missing index).

**Alternative Causes**:
- Connection pool exhaustion
- Memory leaks in application
- Unoptimized query joins
- Large data transfers (N+1 queries)

---

### Scenario 4: "Private Instances Can't Download Updates" — No Internet Access

**Error**: `sudo apt-get update` hangs indefinitely

**Debugging Path**:

```bash
# Step 1: Is NAT Gateway running?
aws ec2 describe-nat-gateways --filter Name=state,Values=available
# If empty: No NAT Gateway ✗

# Step 2: Check route table:
aws ec2 describe-route-tables \
  --filters Name=association.subnet-id,Values=subnet-private

# Routes:
# - 10.0.0.0/16 → local ✓
# - 0.0.0.0/0 → nat-xxxxx ✓

# Step 3: Can app reach internet?
# SSH to instance:
curl https://checkip.amazonaws.com
# Timeout ✗

# Step 4: Security group allows outbound?
aws ec2 describe-security-groups --group-ids sg-app | grep Egress
# TCP 443 to 0.0.0.0/0: MISSING ✗

# Fix:
aws ec2 authorize-security-group-egress \
  --group-id sg-app \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Test:
curl https://checkip.amazonaws.com
# 203.0.113.2 (NAT Gateway IP) ✓

# Try apt-get:
sudo apt-get update
# Success! ✓
```

**Root Cause**: Security group missing outbound HTTPS rule.

**Alternative Check**: Verify NAT Gateway has an Elastic IP attached:
```bash
aws ec2 describe-nat-gateways --nat-gateway-ids nat-xxxxx
# State: available ✓
# Status: available ✓
# AllocationId: eipalloc-xxxxx (Elastic IP) ✓
```

---

### Scenario 5: "WAF Blocking Legitimate Users" — 403 Access Denied

**Error**: Some users see 403 Forbidden from CloudFront

**Debugging Path**:

```bash
# Step 1: Check WAF logs
aws logs tail /aws/wafv2/cloudfront --follow | grep BLOCK

# Sample blocked request:
# {
#   "action": "BLOCK",
#   "terminatingRuleId": "RateLimitRule",
#   "httpSourceIp": "203.0.113.50",
# }

# Step 2: Identify the rule blocking:
# terminatingRuleId: "RateLimitRule"

# Step 3: Check rate limit threshold
aws wafv2 get-web-acl --name production-acl --scope CLOUDFRONT --region us-east-1 \
  | grep -A 10 RateBasedStatement

# Limit: 2000 requests/5 minutes (too strict for office testing)

# Solution A: Whitelist office IP
aws wafv2 create-ip-set \
  --name office-whitelist \
  --scope CLOUDFRONT \
  --ip-address-version IPV4 \
  --addresses '["203.0.113.50/32"]' \
  --region us-east-1

# Solution B: Increase rate limit threshold (be careful)
aws wafv2 update-web-acl \
  --name production-acl \
  --scope CLOUDFRONT \
  --region us-east-1 \
  --rules file://updated-rules.json  # Increase limit to 5000

# Solution C: Use test mode (Count instead of Block)
aws wafv2 update-rule-group \
  --override-action Count  # Doesn't block, just counts
```

**Root Cause**: Rate limiting rule too strict OR legitimate traffic spike.

---

### Scenario 6: "Intermittent Failures" — Some Requests Succeed, Others Fail

**Error**: Occasional 502 Bad Gateway or connection timeouts (not consistent)

**Debugging Path**:

```bash
# Step 1: Check target health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
# Status: MIXED (some healthy, some unhealthy)

# Step 2: Check ALB access logs
aws logs tail /aws/alb/access-logs --follow

# Look for patterns:
# - Some targets getting requests, others not
# - HTTP 502 responses from specific targets
# - Connection reset errors

# Step 3: Check individual target health
for target in $TARGETS; do
  curl http://$target:8080/health
done
# Some return 200, others timeout

# Step 4: SSH to failing target and check:
# - Application process running? (ps aux | grep app)
# - Logs for errors (tail -f /var/log/app.log)
# - Memory/CPU (free -h, top)
# - Disk space (df -h)

# Step 5: Check health check settings
aws elbv2 describe-target-groups --target-group-arns $TG_ARN

# Look for:
# - HealthCheckPath: /health (correct?)
# - HealthCheckProtocol: HTTP (correct?)
# - HealthCheckPort: 8080 (correct?)
# - HealthyThresholdCount: 2 (targets marked healthy after 2 checks)
# - UnhealthyThresholdCount: 2 (targets marked unhealthy after 2 failures)

# Step 6: Restart failing targets (one at a time)
# Drain connections first:
aws elbv2 modify-target-group-attributes \
  --target-group-arn $TG_ARN \
  --attributes Key=deregistration_delay.timeout_seconds,Value=120

# Deregister target
aws elbv2 deregister-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID

# Wait 120 seconds for connections to drain
sleep 120

# Check application logs and restart if needed
sudo systemctl restart myapp

# Re-register target
aws elbv2 register-targets \
  --target-group-arn $TG_ARN \
  --targets Id=$INSTANCE_ID

# Verify health
aws elbv2 describe-target-health --target-group-arn $TG_ARN
# Status: Healthy ✓
```

**Root Causes**:
- Unbalanced traffic distribution
- Resource exhaustion (memory, connections)
- Application crashes or hangs
- Database connection pool exhaustion
- Uneven health check results

---

## ✅ Validation Checklist

### DNS Layer (Route 53)
- [ ] Domain resolves to correct IP: `nslookup app.example.com`
- [ ] Health checks passing in Route 53 console
- [ ] TTL values appropriate (60-300 seconds recommended)
- [ ] Failover routing working (if configured)

### CDN & Security Layer (CloudFront + WAF)
- [ ] CloudFront distribution deployed and enabled
- [ ] Cache behaviors configured for each URL pattern
- [ ] WAF enabled with managed rules
- [ ] SSL certificate valid (not expired)
- [ ] Test: `curl -I https://app.example.com -v` returns 200 with X-Cache header

### Load Balancing Layer (ALB)
- [ ] ALB deployed in multiple AZs
- [ ] Listeners configured (80→443 redirect, HTTPS on 443)
- [ ] Target groups created with targets registered
- [ ] Health checks passing
- [ ] Test: `curl https://alb-dns.elb.amazonaws.com` succeeds

### Network Layer (VPC + Routing)
- [ ] VPC created with proper CIDR (10.0.0.0/16 or similar)
- [ ] Public subnets in 2+ AZs with Internet Gateway route
- [ ] Private subnets in 2+ AZs with NAT Gateway route
- [ ] Route tables correctly associated
- [ ] All expected routes present

### Security Layer (Security Groups)
- [ ] ALB SG allows inbound 80, 443 from 0.0.0.0/0
- [ ] App SG allows inbound 8080 from ALB SG only
- [ ] App SG allows outbound to database, external APIs
- [ ] RDS SG allows inbound 3306 from app SG only
- [ ] No unnecessary 0.0.0.0/0 inbound rules

### Egress Control (NAT Gateway)
- [ ] NAT Gateway deployed in public subnet
- [ ] Elastic IP allocated and attached
- [ ] Private route table points to NAT for 0.0.0.0/0
- [ ] Test: Private instance can `curl https://checkip.amazonaws.com`
- [ ] Returns NAT Gateway public IP, not instance private IP

### Application & Database Layer
- [ ] Application servers running and healthy
- [ ] Application health check endpoint responds 200
- [ ] Application can connect to database
- [ ] Database queries executing successfully
- [ ] Application can call external APIs
- [ ] CloudWatch logs showing normal operation

### End-to-End Validation
- [ ] User's browser → CloudFront → ALB → App → Database → Response
- [ ] Latency < 1 second (CloudFront cache hit < 100ms)
- [ ] Error rate < 0.1% (monitor in CloudWatch)
- [ ] Cache hit ratio > 80% (for static content)
- [ ] SSL Labs score A+ (SSL configuration optimal)

---

## 📚 Next Steps & Integration

This module should be the **0th module** — **read first**, refer back often when debugging.

After understanding complete traffic flow, build Modules 01-10:

1. **Module 01**: VPC Networking Basics (CIDR, subnets, routing)
2. **Module 02**: Secure S3 Static Website (CloudFront + S3)
3. **Module 03**: Multi-Tier App (ALB, ASG, RDS)
4. **Module 04**: Transit Gateway Hub-and-Spoke (multi-VPC)
5. **Module 05**: Site-to-Site VPN Lab (hybrid connectivity)
6. **Module 06**: Direct Connect (enterprise hybrid)
7. **Module 07**: Regional NAT Gateway (high availability)
8. **Module 08**: Secure Hybrid Network (capstone)
9. **Module 09**: Zero-Trust Internal API (security patterns)
10. **Module 10**: Network Security (WAF, Shield)

**Use This Module When**:
- Debugging multi-layer issues
- Onboarding new team members
- Planning architecture changes
- Investigating production incidents
- Conducting post-mortems

---

## 🔗 Appendix: Advanced Troubleshooting

### Complete Troubleshooting Flowchart

```
Issue: "Application Unreachable"
│
├─ Is DNS working? (nslookup app.example.com)
│  ├─ No → Check Route 53 hosted zone, health checks
│  └─ Yes ↓
├─ Is CloudFront reachable? (curl -I https://IP)
│  ├─ No → Check CloudFront distribution status
│  └─ Yes ↓
├─ Is ALB reachable? (curl -I https://alb-dns)
│  ├─ No → Check ALB status, security group
│  └─ Yes ↓
├─ Are targets healthy? (aws elbv2 describe-target-health)
│  ├─ No → Check app security group, health check path
│  └─ Yes ↓
├─ Is app responding? (curl http://target:8080)
│  ├─ No → SSH to instance, check logs, app service status
│  └─ Yes ↓
├─ Can app reach database? (check app logs)
│  ├─ No → Check RDS security group, database connectivity
│  └─ Yes ↓
└─ Issue resolved → Application working ✓
```

### Layer-by-Layer Debugging Commands

```bash
# Layer 1: DNS
nslookup app.example.com
dig app.example.com +trace
aws route53 list-resource-record-sets --hosted-zone-id Z123456

# Layer 2: CloudFront
curl -I https://app.example.com -v  # Check cache headers
aws cloudfront list-distributions
aws logs tail /aws/cloudfront/access-logs

# Layer 3: ALB
curl -I https://alb-dns.elb.amazonaws.com -v
aws elbv2 describe-load-balancers
aws elbv2 describe-target-health --target-group-arn arn:aws:...

# Layer 4: VPC Routing
aws ec2 describe-route-tables --route-table-ids rtb-123456
aws ec2 describe-route-tables --filters Name=association.subnet-id,Values=subnet-123456

# Layer 5-7: Security Groups
aws ec2 describe-security-groups --group-ids sg-12345678
# Check: inbound rules, outbound rules, referenced SGs

# Layer 8: Application
ssh ec2-user@app-instance
curl http://localhost:8080/health
tail -f /var/log/app.log

# Layer 9: Database
mysql -h rds-endpoint -u user -p
SELECT COUNT(*) FROM information_schema.tables;

# Layer 10: NAT Gateway
curl https://checkip.amazonaws.com  # Should return NAT Gateway public IP
```

---

## 🔗 Related Resources

- [AWS Well-Architected Framework — Networking](https://docs.aws.amazon.com/wellarchitected/latest/userguide/workload-review-rel-networking.html)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Introduction.html)
- [AWS ALB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [VPC Reachability Analyzer](https://docs.aws.amazon.com/vpc/latest/reachability/) — Visualize traffic paths
- [CloudWatch Monitoring](https://docs.aws.amazon.com/cloudwatch/latest/userguide/)

---

**Last Updated**: September 2026  
**Version**: 2.0 - Refactored Complete Traffic Flow Guide  
**Windows Support**: Full PowerShell integration available in POWERSHELL_COMMANDS.ps1

