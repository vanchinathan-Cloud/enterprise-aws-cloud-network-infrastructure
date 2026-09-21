TROUBLESHOOTING DECISION 
# Scenario 3: High Latency - Requests Taking 5+ Seconds

## Problem
Response time increased from 200ms to 5000ms+

## Debugging Path

### 1. Identify Which Layer is Slow
`ash
# Check CloudFront origin latency
aws cloudwatch get-metric-statistics \
  --namespace AWS/CloudFront \
  --metric-name OriginLatency \
  --dimensions Name=DistributionId,Value= \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average

# If > 1000ms, ALB or app is slow
`

### 2. Check ALB Target Response Time
`ash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/alb-name/123456 \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average

# If > 1000ms, app or database is slow
`

### 3. Check Application Performance
`ash
# SSH to app instance and test health endpoint
time curl http://localhost:8080/health
# Look at "real" time
# Should be < 100ms

# If > 1000ms, app is slow
`

### 4. Profile Application
`ash
# Check if app is waiting on database
tail -f /var/log/app.log | grep "query_time"

# If query times are high, database is the bottleneck
`

### 5. Optimize Database Queries
`ash
# SSH to RDS instance (or use AWS Systems Manager)
mysql -h rds-endpoint -u admin -p

# Check slow query log
SELECT * FROM mysql.slow_log;

# Look for queries > 1 second
# Add indexes to problematic tables:
CREATE INDEX idx_user_id ON users(user_id);
ANALYZE TABLE users;
`

### 6. Verify Improvement
`ash
# Retest health endpoint
time curl http://localhost:8080/health
# Should now be < 100ms

# Recheck ALB metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --start-time 2024-01-02T00:00:00Z \
  --end-time 2024-01-03T00:00:00Z \
  --period 300 \
  --statistics Average
# Should be < 100ms
`

## Root Causes (Most Common)
1. ❌ Slow database query (missing index) (60%)
2. ❌ N+1 database queries in application (20%)
3. ❌ External API call timeout (10%)
4. ❌ NAT Gateway bandwidth limit (5%)
5. ❌ CloudFront origin misconfigured (5%)

## Solution
`ash
# 1. Identify slow query
SELECT * FROM mysql.slow_log WHERE query_time > 1;

# 2. Add index
CREATE INDEX idx_lookup ON table_name(lookup_column);

# 3. Reanalyze
ANALYZE TABLE table_name;

# 4. Monitor improvement
watch -n1 'tail -5 /var/log/app.log'

# 5. Restart app to clear cache
sudo systemctl restart app-service

# 6. Verify
time curl http://localhost:8080/api/endpoint
# Should be < 100ms now
`

## Prevention
- Enable slow query log in RDS
- Set slow_query_log_file to CloudWatch Logs
- Regular performance profiling (weekly)
- Load testing before production deployment
- Monitor TargetResponseTime in CloudWatch
