TROUBLESHOOTING DECISION TREE
# Scenario 1: Connection Timeout - Users Can't Reach Application

## Problem
Users report: "Connection timeout" when visiting https://app.example.com

## Debugging Path

### 1. Test DNS Resolution
`ash
nslookup app.example.com
# Expected: 203.0.113.1 (CloudFront IP)
# Issue: No output, timeout, or NXDOMAIN
`

### 2. Test CloudFront Connectivity
`ash
curl -I https://203.0.113.1
# Expected: HTTP 200 or 400 (OK or error)
# Issue: Connection timeout
`

### 3. Check ALB Status
`ash
aws elbv2 describe-load-balancers --load-balancer-arns arn:aws:...
# Expected: State: active
# Issue: State: inactive or provisioning
`

### 4. Check Target Health (Root Cause Usually Here!)
`ash
aws elbv2 describe-target-health --target-group-arn arn:aws:...
# Expected: TargetHealth.State = healthy
# Issue: TargetHealth.State = unhealthy or no targets
`

If unhealthy, investigate:
`ash
# Check app security group
aws ec2 describe-security-groups --group-ids sg-app
# Look for: TCP 8080 from sg-alb in IpPermissions

# If missing, add it:
aws ec2 authorize-security-group-ingress \
  --group-id sg-app \
  --protocol tcp \
  --port 8080 \
  --source-group sg-alb
`

### 5. Verify Targets Are Running
`ash
aws ec2 describe-instances --instance-ids i-12345678
# Expected: State: running
# Issue: State: stopped or terminated
`

## Root Causes (Most Common)
1. ❌ App security group doesn't allow ALB (80%)
2. ❌ Target group health check misconfigured (10%)
3. ❌ No targets registered (5%)
4. ❌ ALB security group blocks inbound (5%)

## Solution
`ash
# Add missing security group rule:
aws ec2 authorize-security-group-ingress \
  --group-id sg-app \
  --protocol tcp \
  --port 8080 \
  --source-group sg-alb

# Wait 30 seconds for health check
sleep 30

# Verify targets are healthy
aws elbv2 describe-target-health --target-group-arn arn:aws:...
# Expected: State = healthy

# Test
curl https://app.example.com
# Expected: 200 OK
`

## Prevention
- Always add app security group rule BEFORE registering targets
- Test health check endpoint manually before deploying
- Use IaC (Terraform) to prevent manual mistakes

