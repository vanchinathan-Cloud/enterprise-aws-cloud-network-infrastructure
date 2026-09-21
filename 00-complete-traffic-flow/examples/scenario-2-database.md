TROUBLESHOOTING DECISION 
# Scenario 2: Database Connection Timeout

## Problem
Application logs show: ERROR: timeout waiting for connection to database

## Debugging Path

### 1. Verify RDS is Running
`ash
aws rds describe-db-instances --db-instance-identifier prod-db
# Expected: DBInstanceStatus = available
# Issue: DBInstanceStatus = creating, deleting, or failed
`

### 2. Test Connectivity to Database Port
`ash
# SSH to app server and test
nc -zv rds-prod.us-east-1.rds.amazonaws.com 3306
# Expected: succeeded
# Issue: failed or timeout

# If failed, check security group...
`

### 3. Check RDS Security Group
`ash
aws ec2 describe-security-groups --group-ids sg-rds
# Look for: TCP 3306 from sg-app in IpPermissions
# Issue: Rule missing or wrong source
`

### 4. Add Missing Security Group Rule
`ash
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 3306 \
  --source-group sg-app
`

### 5. Test Database Connectivity
`ash
# SSH to app server
ssh -i key.pem ec2-user@app-instance

# Try connecting to database
mysql -h rds-prod.us-east-1.rds.amazonaws.com -u admin -p
# Enter password
# Expected: Welcome to MySQL prompt
`

### 6. Verify App Credentials
`ash
# Check app config
cat /etc/app-config/database.yml
# Verify: hostname, port, username, password

# Test with those credentials
mysql -h  -u  -p
`

## Root Causes (Most Common)
1. ❌ RDS security group doesn't allow app source (90%)
2. ❌ Database credentials wrong (5%)
3. ❌ RDS not in correct subnet (3%)
4. ❌ Network ACL blocks 3306 (2%)

## Solution
`ash
# 1. Add security group rule
aws ec2 authorize-security-group-ingress \
  --group-id sg-rds \
  --protocol tcp \
  --port 3306 \
  --source-group sg-app

# 2. Verify app can reach port
nc -zv rds-endpoint 3306  # Should succeed

# 3. Test with mysql client
mysql -h rds-endpoint -u user -p

# 4. Restart app service
sudo systemctl restart app-service

# 5. Check logs
tail -f /var/log/app.log
# Should show: "Successfully connected to database"
`

## Prevention
- Create RDS security group rule BEFORE launching app
- Document security group rules in README
- Use IaC to prevent manual configuration drift
- Add database connectivity test to deployment checklist

