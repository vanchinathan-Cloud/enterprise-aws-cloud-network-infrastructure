<#
================================================================================
Module 00: Complete AWS Traffic Flow - PowerShell Commands Cheat Sheet
================================================================================

This file contains copy-paste ready PowerShell commands for debugging all 11 
network layers. Update the variables at the top, then copy-paste individual
commands as needed.

================================================================================
#>

# ============================================================================
# CONFIGURATION - UPDATE THESE WITH YOUR VALUES
# ============================================================================

$DomainName = "app.example.com"
$ALBDnsName = "my-alb-123456789.us-east-1.elb.amazonaws.com"
$RDSEndpoint = "rds-prod.us-east-1.rds.amazonaws.com"
$TargetGroupArn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-targets/1234567890123456"
$LoadBalancerArn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/my-alb/1234567890123456"
$ALBSecurityGroup = "sg-alb"
$AppSecurityGroup = "sg-app"
$RDSSecurityGroup = "sg-rds"
$VPCId = "vpc-12345678"
$PrivateSubnetId = "subnet-12345678"
$PublicSubnetId = "subnet-87654321"

# ============================================================================
# LAYER 1: DNS RESOLUTION (Route 53)
# ============================================================================

Write-Host "`n=== LAYER 1: DNS RESOLUTION ===" -ForegroundColor Cyan

# Test DNS resolution
Resolve-DnsName -Name $DomainName

# Get detailed DNS info
Resolve-DnsName -Name $DomainName -Type A

# Test multiple DNS servers
Resolve-DnsName -Name $DomainName -Server 8.8.8.8

# Get Route 53 hosted zones
Get-R53HostedZones

# Get DNS records for domain
$hostedZoneId = (Get-R53HostedZones | Where-Object Name -eq "$DomainName.").Id
Get-R53ResourceRecordSets -HostedZoneId $hostedZoneId

# Check Route 53 health checks
Get-R53HealthCheck | Format-Table -Property Id, HealthCheckConfig

# ============================================================================
# LAYER 2: CLOUDFRONT + WAF
# ============================================================================

Write-Host "`n=== LAYER 2: CLOUDFRONT + WAF ===" -ForegroundColor Cyan

# Test HTTPS connectivity with detailed headers
Invoke-WebRequest -Uri "https://$DomainName" -Method Head -Verbose

# Check cache status
$cf_response = Invoke-WebRequest -Uri "https://$DomainName" -Method Head
$cf_response.Headers | Where-Object { $_.Key -like "*cache*" -or $_.Key -like "*x-amzn*" }

# List CloudFront distributions
Get-CFDistribution

# Get CloudFront distribution details
Get-CFDistribution | Where-Object DomainName -eq $DomainName | Format-List *

# Check WAF Web ACLs
Get-WAFv2WebACL -Scope CLOUDFRONT

# Get WAF logging configuration
Get-WAFv2WebACL -Name "production-acl" -Scope CLOUDFRONT -Region us-east-1

# Check CloudFront metrics (last hour)
$cfMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/CloudFront" `
  -MetricName "OriginLatency" `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"
$cfMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Average

# Check CloudFront cache hit ratio
$cacheMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/CloudFront" `
  -MetricName "CacheBytesHit" `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Sum"
$cacheMetrics.Datapoints | Format-Table Timestamp, Sum

# ============================================================================
# LAYER 3: APPLICATION LOAD BALANCER
# ============================================================================

Write-Host "`n=== LAYER 3: APPLICATION LOAD BALANCER ===" -ForegroundColor Cyan

# Test ALB connectivity
Invoke-WebRequest -Uri "https://$ALBDnsName" -Method Head -Verbose

# Get all load balancers
Get-ELBv2LoadBalancer | Format-Table LoadBalancerName, State, Scheme

# Get specific ALB details
Get-ELBv2LoadBalancer -LoadBalancerArns $LoadBalancerArn

# List ALB listeners
Get-ELBv2Listener -LoadBalancerArn $LoadBalancerArn

# Get listener rules
Get-ELBv2Rule -ListenerArn (Get-ELBv2Listener -LoadBalancerArn $LoadBalancerArn).ListenerArn[0]

# Check ALB target groups
Get-ELBv2TargetGroup -LoadBalancerArn $LoadBalancerArn

# Get ALB metrics (request count)
$albMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/ApplicationELB" `
  -MetricName "RequestCount" `
  -Dimensions @(@{Name="LoadBalancer"; Value="app/my-alb/1234567890123456"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Sum"
$albMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Sum

# Check ALB HTTP error rate
$errorMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/ApplicationELB" `
  -MetricName "HTTPCode_Target_5XX_Count" `
  -Dimensions @(@{Name="LoadBalancer"; Value="app/my-alb/1234567890123456"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Sum"
$errorMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Sum

# ============================================================================
# LAYER 3+: TARGET GROUP HEALTH
# ============================================================================

Write-Host "`n=== LAYER 3+: TARGET GROUP HEALTH ===" -ForegroundColor Cyan

# Check target health status
Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn | Format-Table `
  @{Name="Instance"; Expression={$_.Target.Id}}, `
  @{Name="State"; Expression={$_.TargetHealth.State}}, `
  @{Name="Reason"; Expression={$_.TargetHealth.Reason}} `
  -AutoSize

# Get unhealthy targets
Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn | Where-Object { $_.TargetHealth.State -ne "healthy" }

# Deregister a target (for maintenance)
Unregister-ELBv2Target `
  -TargetGroupArn $TargetGroupArn `
  -Targets @(@{Id = "i-12345678"; Port = 8080})

# Register a target
Register-ELBv2Target `
  -TargetGroupArn $TargetGroupArn `
  -Targets @(@{Id = "i-12345678"; Port = 8080})

# Get target group health check configuration
$tg = Get-ELBv2TargetGroup -TargetGroupArns $TargetGroupArn
$tg | Select-Object -Property `
  HealthCheckEnabled, `
  HealthCheckProtocol, `
  HealthCheckPath, `
  HealthCheckPort, `
  HealthCheckIntervalSeconds, `
  HealthyThresholdCount, `
  UnhealthyThresholdCount

# ============================================================================
# LAYER 4: VPC NETWORKING & ROUTING
# ============================================================================

Write-Host "`n=== LAYER 4: VPC NETWORKING & ROUTING ===" -ForegroundColor Cyan

# List all VPCs
Get-EC2Vpc | Format-Table VpcId, CidrBlock, State

# Get VPC details
Get-EC2Vpc -VpcIds $VPCId | Format-List *

# List subnets in VPC
Get-EC2Subnet -Filters @(@{Name="vpc-id"; Values=$VPCId}) | `
  Format-Table SubnetId, CidrBlock, AvailabilityZone, State

# List route tables
Get-EC2RouteTable -Filters @(@{Name="vpc-id"; Values=$VPCId}) | Format-Table RouteTableId, Tags

# Get specific route table routes
$rt = Get-EC2RouteTable -RouteTableIds "rtb-12345678"
$rt.Routes | Format-Table `
  DestinationCidrBlock, `
  GatewayId, `
  NatGatewayId, `
  InstanceId, `
  NetworkInterfaceId, `
  State

# Find route table for specific subnet
Get-EC2RouteTableAssociation -Filters @(@{Name="subnet-id"; Values=$PrivateSubnetId})

# Check if subnet is public (has IGW route)
$subnetRt = Get-EC2RouteTableAssociation -Filters @(@{Name="subnet-id"; Values=$PrivateSubnetId})
$routes = (Get-EC2RouteTable -RouteTableIds $subnetRt.RouteTableId).Routes
$hasIgw = $routes | Where-Object { $_.GatewayId -like "igw-*" }
Write-Host "Subnet $PrivateSubnetId is $(if ($hasIgw) { 'PUBLIC' } else { 'PRIVATE' })"

# List Internet Gateways
Get-EC2InternetGateway -Filters @(@{Name="attachment.vpc-id"; Values=$VPCId})

# List NAT Gateways
Get-EC2NatGateway -Filters @(@{Name="vpc-id"; Values=$VPCId})

# ============================================================================
# LAYER 5+7: SECURITY GROUPS
# ============================================================================

Write-Host "`n=== LAYER 5+7: SECURITY GROUPS ===" -ForegroundColor Cyan

# List all security groups in VPC
Get-EC2SecurityGroup -Filters @(@{Name="vpc-id"; Values=$VPCId}) | `
  Format-Table GroupId, GroupName

# Get security group details
Get-EC2SecurityGroup -GroupIds $ALBSecurityGroup

# Get inbound rules (more detailed)
$sg = Get-EC2SecurityGroup -GroupIds $AppSecurityGroup
$sg.IpPermissions | Select-Object -Property `
  IpProtocol, `
  FromPort, `
  ToPort, `
  @{Name="CidrIp"; Expression={$_.IpRanges.CidrIp}}, `
  @{Name="SourceSecurityGroup"; Expression={$_.UserIdGroupPairs.GroupId}} | `
  Format-Table -AutoSize

# Get outbound rules
$sg.IpPermissionsEgress | Format-Table IpProtocol, FromPort, ToPort

# Add inbound rule for HTTP
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 80
$permission.ToPort = 80
$permission.IpRanges.Add("0.0.0.0/0")
Grant-EC2SecurityGroupIngress -GroupId $ALBSecurityGroup -IpPermission $permission

# Add inbound rule for HTTPS
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 443
$permission.ToPort = 443
$permission.IpRanges.Add("0.0.0.0/0")
Grant-EC2SecurityGroupIngress -GroupId $ALBSecurityGroup -IpPermission $permission

# Add inbound rule from ALB SG to App SG (port 8080)
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 8080
$permission.ToPort = 8080
$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = $ALBSecurityGroup}))
Grant-EC2SecurityGroupIngress -GroupId $AppSecurityGroup -IpPermission $permission

# Add inbound rule for RDS from App SG (port 3306)
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 3306
$permission.ToPort = 3306
$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = $AppSecurityGroup}))
Grant-EC2SecurityGroupIngress -GroupId $RDSSecurityGroup -IpPermission $permission

# Add outbound rule for App SG to access external HTTPS
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 443
$permission.ToPort = 443
$permission.IpRanges.Add("0.0.0.0/0")
Grant-EC2SecurityGroupEgress -GroupId $AppSecurityGroup -IpPermission $permission

# Remove an inbound rule
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 22
$permission.ToPort = 22
$permission.IpRanges.Add("0.0.0.0/0")
Revoke-EC2SecurityGroupIngress -GroupId $AppSecurityGroup -IpPermission $permission

# ============================================================================
# LAYER 8: APPLICATION CONNECTIVITY
# ============================================================================

Write-Host "`n=== LAYER 8: APPLICATION CONNECTIVITY ===" -ForegroundColor Cyan

# Test application health endpoint
Invoke-WebRequest -Uri "http://localhost:8080/health" -Method Get

# Test from specific server (via SSH/RDP, then run):
# curl http://localhost:8080/health
# curl -I https://app.example.com

# Check CloudWatch logs for application
Get-CWLogEvents -LogGroupName "/aws/app/production" -LogStreamName "app-1" | `
  Select-Object -ExpandProperty Events | Format-Table Timestamp, Message

# Get recent error logs
Get-CWLogEvents -LogGroupName "/aws/app/production" -LogStreamName "app-1" | `
  Select-Object -ExpandProperty Events | `
  Where-Object { $_.Message -like "*ERROR*" } | `
  Format-Table Timestamp, Message

# ============================================================================
# LAYER 9: RDS DATABASE
# ============================================================================

Write-Host "`n=== LAYER 9: RDS DATABASE ===" -ForegroundColor Cyan

# List all RDS instances
Get-RDSDBInstance | Format-Table DBInstanceIdentifier, DBInstanceStatus, Engine

# Get RDS instance details
Get-RDSDBInstance -DBInstanceIdentifier "prod-db" | Format-List *

# Check RDS endpoint
(Get-RDSDBInstance -DBInstanceIdentifier "prod-db").Endpoint

# Test RDS connectivity
Test-NetConnection -ComputerName $RDSEndpoint -Port 3306

# Check RDS security group
Get-EC2SecurityGroup -GroupIds $RDSSecurityGroup | Select-Object -ExpandProperty IpPermissions

# Check RDS parameter group
Get-RDSDBParameterGroup | Format-Table DBParameterGroupName, Family

# Get RDS metrics (Database Connections)
$rdsMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/RDS" `
  -MetricName "DatabaseConnections" `
  -Dimensions @(@{Name="DBInstanceIdentifier"; Value="prod-db"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"
$rdsMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Average

# Get RDS CPU utilization
$cpuMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/RDS" `
  -MetricName "CPUUtilization" `
  -Dimensions @(@{Name="DBInstanceIdentifier"; Value="prod-db"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"
$cpuMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Average

# Get RDS free storage space
$storageMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/RDS" `
  -MetricName "FreeStorageSpace" `
  -Dimensions @(@{Name="DBInstanceIdentifier"; Value="prod-db"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"
$storageMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Average

# ============================================================================
# LAYER 10: NAT GATEWAY / EGRESS CONTROL
# ============================================================================

Write-Host "`n=== LAYER 10: NAT GATEWAY / EGRESS CONTROL ===" -ForegroundColor Cyan

# List all NAT Gateways
Get-EC2NatGateway | Format-Table NatGatewayId, State, PublicIp

# Get NAT Gateway details
Get-EC2NatGateway -NatGatewayIds "nat-12345678" | Format-List *

# Get NAT Gateway Elastic IP
Get-EC2NatGateway -Filters @(@{Name="vpc-id"; Values=$VPCId}) | `
  Select-Object -Property NatGatewayId, `
  @{Name="PublicIP"; Expression={$_.NatGatewayAddresses[0].PublicIp}}, `
  @{Name="AllocationId"; Expression={$_.NatGatewayAddresses[0].AllocationId}}

# Check route to NAT Gateway
$rt = Get-EC2RouteTable -RouteTableIds "rtb-12345678"
$rt.Routes | Where-Object { $_.NatGatewayId }

# Test egress connectivity from private instance
# SSH to private instance, then run:
# curl https://checkip.amazonaws.com

# Check NAT Gateway metrics (bytes processed)
$natMetrics = Get-CWMetricStatistic `
  -Namespace "AWS/NatGateway" `
  -MetricName "BytesOutToDestination" `
  -Dimensions @(@{Name="NatGatewayId"; Value="nat-12345678"}) `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Sum"
$natMetrics.Datapoints | Sort-Object Timestamp -Descending | Format-Table Timestamp, Sum

# ============================================================================
# END-TO-END DIAGNOSTICS
# ============================================================================

Write-Host "`n=== END-TO-END DIAGNOSTICS ===" -ForegroundColor Cyan

# Complete flow test (from user perspective)
Write-Host "1. DNS Resolution:" -ForegroundColor Yellow
Resolve-DnsName -Name $DomainName

Write-Host "`n2. CloudFront Reachability:" -ForegroundColor Yellow
$cf_test = Invoke-WebRequest -Uri "https://$DomainName" -Method Head
$cf_test.StatusCode

Write-Host "`n3. ALB Reachability:" -ForegroundColor Yellow
$alb_test = Invoke-WebRequest -Uri "https://$ALBDnsName" -Method Head
$alb_test.StatusCode

Write-Host "`n4. Target Health:" -ForegroundColor Yellow
Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn | Select-Object -Property Target, @{Name="Status"; Expression={$_.TargetHealth.State}}

Write-Host "`n5. Database Connectivity:" -ForegroundColor Yellow
Test-NetConnection -ComputerName $RDSEndpoint -Port 3306

Write-Host "`n6. NAT Gateway Status:" -ForegroundColor Yellow
Get-EC2NatGateway -Filters @(@{Name="vpc-id"; Values=$VPCId}) | Format-Table NatGatewayId, State

# ============================================================================
# TROUBLESHOOTING SCENARIO: CONNECTION TIMEOUT
# ============================================================================

Write-Host "`n=== TROUBLESHOOTING: CONNECTION TIMEOUT ===" -ForegroundColor Yellow

# Step 1: DNS works?
Resolve-DnsName $DomainName

# Step 2: CloudFront reachable?
$cf = Invoke-WebRequest -Uri "https://$DomainName" -Method Head -ErrorAction SilentlyContinue
if ($cf.StatusCode -eq 200) { "CloudFront: OK" } else { "CloudFront: FAILED" }

# Step 3: ALB targets healthy?
$unhealthy = Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn | Where-Object { $_.TargetHealth.State -ne "healthy" }
if ($unhealthy) {
    "TARGETS UNHEALTHY - Checking app security group..."
    Get-EC2SecurityGroup -GroupIds $AppSecurityGroup | Select-Object -ExpandProperty IpPermissions
}

# Step 4: Fix if needed - add app SG inbound rule
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 8080
$permission.ToPort = 8080
$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = $ALBSecurityGroup}))
Grant-EC2SecurityGroupIngress -GroupId $AppSecurityGroup -IpPermission $permission

Write-Host "Fix applied - targets should become healthy in 30-60 seconds"

# ============================================================================
# TROUBLESHOOTING SCENARIO: DATABASE TIMEOUT
# ============================================================================

Write-Host "`n=== TROUBLESHOOTING: DATABASE TIMEOUT ===" -ForegroundColor Yellow

# Step 1: Is RDS running?
$rds = Get-RDSDBInstance -DBInstanceIdentifier "prod-db"
"RDS Status: $($rds.DBInstanceStatus)"

# Step 2: Can reach RDS port?
Test-NetConnection -ComputerName $RDSEndpoint -Port 3306

# Step 3: Check RDS security group
Get-EC2SecurityGroup -GroupIds $RDSSecurityGroup | Select-Object -ExpandProperty IpPermissions

# Step 4: Fix if needed - add RDS SG inbound rule
$permission = New-Object 'Amazon.EC2.Model.IpPermission'
$permission.IpProtocol = "tcp"
$permission.FromPort = 3306
$permission.ToPort = 3306
$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = $AppSecurityGroup}))
Grant-EC2SecurityGroupIngress -GroupId $RDSSecurityGroup -IpPermission $permission

Write-Host "Fix applied - database should be reachable now"

# ============================================================================
# TROUBLESHOOTING SCENARIO: HIGH LATENCY
# ============================================================================

Write-Host "`n=== TROUBLESHOOTING: HIGH LATENCY ===" -ForegroundColor Yellow

# Check CloudFront origin latency
$cfLatency = Get-CWMetricStatistic `
  -Namespace "AWS/CloudFront" `
  -MetricName "OriginLatency" `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"

$avgCfLatency = ($cfLatency.Datapoints | Measure-Object -Property Average -Average).Average
"CloudFront Origin Latency (avg): $avgCfLatency ms"

# Check ALB target response time
$albLatency = Get-CWMetricStatistic `
  -Namespace "AWS/ApplicationELB" `
  -MetricName "TargetResponseTime" `
  -StartTime (Get-Date).AddHours(-1) `
  -EndTime (Get-Date) `
  -Period 300 `
  -Statistics "Average"

$avgAlbLatency = ($albLatency.Datapoints | Measure-Object -Property Average -Average).Average
"ALB Target Response Time (avg): $avgAlbLatency ms"

# Recommendation
if ($avgAlbLatency -gt 1000) {
    "Target response time is high - check application performance and database queries"
}

# ============================================================================
# TROUBLESHOOTING SCENARIO: NO INTERNET ACCESS
# ============================================================================

Write-Host "`n=== TROUBLESHOOTING: NO INTERNET ACCESS ===" -ForegroundColor Yellow

# Check NAT Gateway
$nat = Get-EC2NatGateway -Filters @(@{Name="vpc-id"; Values=$VPCId})
if ($nat) {
    "NAT Gateway found: $($nat.NatGatewayId)"
    "State: $($nat.State)"
    "Public IP: $($nat.NatGatewayAddresses[0].PublicIp)"
} else {
    "NO NAT GATEWAY FOUND - Create one first!"
}

# Check private subnet route table
$subnetRt = Get-EC2RouteTableAssociation -Filters @(@{Name="subnet-id"; Values=$PrivateSubnetId})
$routes = (Get-EC2RouteTable -RouteTableIds $subnetRt.RouteTableId).Routes
$natRoute = $routes | Where-Object { $_.NatGatewayId }

if ($natRoute) {
    "NAT route configured: $($natRoute.DestinationCidrBlock) → $($natRoute.NatGatewayId)"
} else {
    "NO NAT ROUTE - Need to add: 0.0.0.0/0 → NAT Gateway"
}

# Check security group allows outbound HTTPS
$sg = Get-EC2SecurityGroup -GroupIds $AppSecurityGroup
$httpsEgress = $sg.IpPermissionsEgress | Where-Object { $_.FromPort -eq 443 }

if ($httpsEgress) {
    "Outbound HTTPS allowed"
} else {
    "Outbound HTTPS NOT allowed - adding rule..."
    $permission = New-Object 'Amazon.EC2.Model.IpPermission'
    $permission.IpProtocol = "tcp"
    $permission.FromPort = 443
    $permission.ToPort = 443
    $permission.IpRanges.Add("0.0.0.0/0")
    Grant-EC2SecurityGroupEgress -GroupId $AppSecurityGroup -IpPermission $permission
}

# ============================================================================
# END OF POWERSHELL COMMANDS
# ============================================================================

Write-Host "`n=== END OF POWERSHELL COMMANDS ===" -ForegroundColor Cyan
Write-Host "For more information, see: 00-complete-traffic-flow-README-UPDATED.md" -ForegroundColor Cyan
Write-Host "Run: .\Module-00-Validation.ps1 for automated validation`n" -ForegroundColor Cyan

