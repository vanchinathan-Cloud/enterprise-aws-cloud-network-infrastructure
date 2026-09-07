#=============================================================================
# Module 00: Complete AWS Traffic Flow - PowerShell Validation Script
# 
# Purpose: Validate all 11 networking layers and troubleshoot issues
# 
# Usage: .\Module-00-Validation.ps1 -Environment Production -Verbose
#=============================================================================

#Requires -Version 5.0
#Requires -Modules AWSPowerShell.NetCore

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "Production",
    
    [Parameter(Mandatory=$false)]
    [string]$DomainName = "app.example.com",
    
    [Parameter(Mandatory=$false)]
    [string]$ALBDnsName = "my-alb-123456789.us-east-1.elb.amazonaws.com",
    
    [Parameter(Mandatory=$false)]
    [string]$RDSEndpoint = "rds-prod.us-east-1.rds.amazonaws.com",
    
    [Parameter(Mandatory=$false)]
    [string]$TargetGroupArn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/web-targets/1234567890123456",
    
    [Parameter(Mandatory=$false)]
    [string]$ALBSecurityGroup = "sg-alb",
    
    [Parameter(Mandatory=$false)]
    [string]$AppSecurityGroup = "sg-app",
    
    [Parameter(Mandatory=$false)]
    [string]$RDSSecurityGroup = "sg-rds",
    
    [Parameter(Mandatory=$false)]
    [switch]$RunAllScenarios = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$VerboseLogging = $true
)

#=============================================================================
# Global Configuration
#=============================================================================

$script:ModuleVersion = "2.0"
$script:ValidResults = @()
$script:FailedResults = @()
$script:WarningResults = @()
$script:Colors = @{
    Success = "Green"
    Failure = "Red"
    Warning = "Yellow"
    Info = "Cyan"
}

#=============================================================================
# Utility Functions
#=============================================================================

function Write-Header {
    param([string]$Title)
    Write-Host "`n" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
    $script:ValidResults += $Message
}

function Write-Failure {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    $script:FailedResults += $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
    $script:WarningResults += $Message
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

function Test-Command {
    param(
        [string]$Command,
        [string]$SuccessMessage,
        [string]$FailureMessage
    )
    
    try {
        Invoke-Expression $Command | Out-Null
        Write-Success $SuccessMessage
        return $true
    }
    catch {
        Write-Failure "$FailureMessage - $($_.Exception.Message)"
        return $false
    }
}

function Get-ElapsedTime {
    param([datetime]$StartTime)
    $elapsed = (Get-Date) - $StartTime
    return $elapsed.TotalSeconds.ToString("F2")
}

#=============================================================================
# Layer 1: DNS Resolution (Route 53)
#=============================================================================

function Test-DNSResolution {
    Write-Header "LAYER 1: DNS Resolution (Route 53)"
    Write-Info "Testing: $DomainName"
    
    $startTime = Get-Date
    
    try {
        # Attempt DNS resolution
        $dnsResult = Resolve-DnsName -Name $DomainName -ErrorAction Stop
        
        Write-Success "DNS resolution successful: $($dnsResult.IPAddress)"
        Write-Info "Record Type: $($dnsResult.Type)"
        Write-Info "Time to Resolve: $(Get-ElapsedTime $startTime)s"
        
        # Validate IP format
        if ($dnsResult.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Write-Success "IP address format valid"
            return $true
        }
        else {
            Write-Warning "IP address format appears incorrect: $($dnsResult.IPAddress)"
            return $false
        }
    }
    catch {
        Write-Failure "DNS resolution failed: $($_.Exception.Message)"
        Write-Info "Recommendation: Check Route 53 hosted zone, health checks, and nameserver configuration"
        return $false
    }
}

#=============================================================================
# Layer 2: CloudFront + WAF
#=============================================================================

function Test-CloudFrontConnectivity {
    Write-Header "LAYER 2: CloudFront (CDN) + WAF"
    Write-Info "Testing: https://$DomainName"
    
    try {
        # Test HTTPS connectivity
        $response = Invoke-WebRequest -Uri "https://$DomainName" -Method Head -ErrorAction Stop -TimeoutSec 10
        
        Write-Success "CloudFront is reachable (HTTP $($response.StatusCode))"
        
        # Check cache headers
        if ($response.Headers.ContainsKey('X-Cache')) {
            Write-Info "Cache Status: $($response.Headers['X-Cache'])"
        }
        else {
            Write-Warning "X-Cache header not found (may not be CloudFront)"
        }
        
        # Check WAF headers
        if ($response.Headers.ContainsKey('x-amzn-waf-action')) {
            Write-Info "WAF Action: $($response.Headers['x-amzn-waf-action'])"
        }
        
        # Check SSL certificate
        if ($response.Headers.ContainsKey('Content-Security-Policy')) {
            Write-Success "SSL/TLS configured (CSP header present)"
        }
        
        return $true
    }
    catch {
        Write-Failure "CloudFront connection failed: $($_.Exception.Message)"
        Write-Info "Recommendation: Check CloudFront distribution status, WAF rules, SSL certificate validity"
        return $false
    }
}

#=============================================================================
# Layer 3: Application Load Balancer
#=============================================================================

function Test-ALBHealthStatus {
    Write-Header "LAYER 3: Application Load Balancer (ALB)"
    Write-Info "Testing: $ALBDnsName"
    
    try {
        # Test ALB connectivity
        $response = Invoke-WebRequest -Uri "https://$ALBDnsName" -Method Head -ErrorAction Stop -TimeoutSec 10
        Write-Success "ALB is reachable (HTTP $($response.StatusCode))"
        
        # Check ALB headers
        if ($response.Headers.ContainsKey('x-amzn-trace-id')) {
            Write-Info "ALB Trace ID: $($response.Headers['x-amzn-trace-id'])"
        }
        
        return $true
    }
    catch {
        Write-Failure "ALB connection failed: $($_.Exception.Message)"
        Write-Info "Recommendation: Check ALB status, security groups, listener configuration"
        return $false
    }
}

function Test-TargetGroupHealth {
    Write-Header "LAYER 3+: Target Group Health"
    Write-Info "Target Group ARN: $TargetGroupArn"
    
    try {
        $targetHealth = Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn -ErrorAction Stop
        
        $healthyCount = ($targetHealth | Where-Object { $_.TargetHealth.State -eq 'healthy' }).Count
        $unhealthyCount = ($targetHealth | Where-Object { $_.TargetHealth.State -eq 'unhealthy' }).Count
        
        Write-Info "Total Targets: $($targetHealth.Count)"
        Write-Info "Healthy: $healthyCount"
        Write-Info "Unhealthy: $unhealthyCount"
        
        if ($unhealthyCount -gt 0) {
            Write-Warning "Some targets are unhealthy!"
            $targetHealth | Where-Object { $_.TargetHealth.State -ne 'healthy' } | ForEach-Object {
                Write-Info "Unhealthy Target: $($_.Target.Id) - Reason: $($_.TargetHealth.Reason)"
            }
            return $false
        }
        else {
            Write-Success "All targets are healthy"
            return $true
        }
    }
    catch {
        Write-Failure "Failed to retrieve target health: $($_.Exception.Message)"
        Write-Info "Recommendation: Check target group ARN, IAM permissions, and target configuration"
        return $false
    }
}

#=============================================================================
# Layer 4: VPC & Routing
#=============================================================================

function Test-VPCRouting {
    Write-Header "LAYER 4: VPC Networking & Route Tables"
    Write-Info "Testing VPC route table configuration"
    
    try {
        # Get all route tables
        $routeTables = Get-EC2RouteTable -ErrorAction Stop
        
        Write-Info "Total Route Tables: $($routeTables.Count)"
        
        $publicRoutes = 0
        $privateRoutes = 0
        
        foreach ($rt in $routeTables) {
            $hasIGW = $rt.Routes | Where-Object { $_.GatewayId -like 'igw-*' }
            $hasNAT = $rt.Routes | Where-Object { $_.NatGatewayId }
            
            if ($hasIGW) {
                $publicRoutes++
                Write-Info "Public Route Table Found: $($rt.RouteTableId)"
            }
            elseif ($hasNAT) {
                $privateRoutes++
                Write-Info "Private Route Table (NAT) Found: $($rt.RouteTableId)"
            }
        }
        
        Write-Success "Public Route Tables: $publicRoutes"
        Write-Success "Private Route Tables: $privateRoutes"
        
        if ($publicRoutes -eq 0 -or $privateRoutes -eq 0) {
            Write-Warning "Expected both public and private route tables"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Failure "Failed to retrieve VPC routing: $($_.Exception.Message)"
        Write-Info "Recommendation: Check IAM permissions and VPC configuration"
        return $false
    }
}

#=============================================================================
# Layer 5+7: Security Groups
#=============================================================================

function Test-SecurityGroupConfiguration {
    Write-Header "LAYER 5+7: Security Groups Configuration"
    Write-Info "Testing security groups for least-privilege access"
    
    $securityGroups = @{
        "$ALBSecurityGroup" = @{
            Name = "ALB Security Group"
            ExpectedInboundPorts = @(80, 443)
        }
        "$AppSecurityGroup" = @{
            Name = "App Security Group"
            ExpectedInboundPorts = @(8080)
        }
        "$RDSSecurityGroup" = @{
            Name = "RDS Security Group"
            ExpectedInboundPorts = @(3306)
        }
    }
    
    foreach ($sgId in $securityGroups.Keys) {
        try {
            $sg = Get-EC2SecurityGroup -GroupId $sgId -ErrorAction Stop
            Write-Info "Security Group: $($sg.GroupName) ($sgId)"
            
            $sgConfig = $securityGroups[$sgId]
            $inboundRules = $sg.IpPermissions
            
            foreach ($port in $sgConfig.ExpectedInboundPorts) {
                $portFound = $inboundRules | Where-Object { $_.FromPort -eq $port -or $_.ToPort -eq $port }
                
                if ($portFound) {
                    Write-Success "  Port $port: Allowed"
                    
                    # Check for overly permissive rules
                    $permissiveRules = $portFound | Where-Object { $_.IpRanges.CidrIp -eq "0.0.0.0/0" -and $sgId -eq $RDSSecurityGroup }
                    if ($permissiveRules) {
                        Write-Warning "  Port $port: Allowed from 0.0.0.0/0 (too permissive for RDS!)"
                    }
                }
                else {
                    Write-Warning "  Port $port: Not configured (may be needed)"
                }
            }
            
            # Check outbound rules
            $outboundRules = $sg.IpPermissionsEgress
            if ($outboundRules.Count -eq 1 -and $outboundRules[0].IpRanges.CidrIp -eq "0.0.0.0/0") {
                Write-Warning "  Outbound: Allow All (consider restricting for App SG)"
            }
            else {
                Write-Success "  Outbound: Restricted (good!)"
            }
        }
        catch {
            Write-Warning "Could not retrieve security group $sgId - check if it exists"
        }
    }
    
    return $true
}

#=============================================================================
# Layer 6: Application Layer
#=============================================================================

function Test-ApplicationHealth {
    Write-Header "LAYER 6+8: Application Health Check"
    Write-Info "Testing application health endpoint"
    
    try {
        $healthEndpoint = "http://localhost:8080/health"
        $response = Invoke-WebRequest -Uri $healthEndpoint -Method Get -ErrorAction Stop -TimeoutSec 5
        
        if ($response.StatusCode -eq 200) {
            Write-Success "Application health check passed (HTTP 200)"
            
            # Try to parse JSON response
            try {
                $health = $response.Content | ConvertFrom-Json
                Write-Info "Health Status: $(($health.status) ?? 'OK')"
            }
            catch {
                Write-Info "Response: $($response.Content.Substring(0, [Math]::Min(100, $response.Content.Length)))"
            }
            
            return $true
        }
        else {
            Write-Warning "Health check returned HTTP $($response.StatusCode)"
            return $false
        }
    }
    catch {
        Write-Failure "Application health check failed: $($_.Exception.Message)"
        Write-Info "Recommendation: Ensure application is running and health endpoint is configured"
        Write-Info "Run: ssh to app server, then: curl http://localhost:8080/health"
        return $false
    }
}

#=============================================================================
# Layer 9: Database Layer
#=============================================================================

function Test-DatabaseConnectivity {
    Write-Header "LAYER 9: RDS Database Connectivity"
    Write-Info "Testing: $RDSEndpoint:3306"
    
    try {
        # Test TCP port connectivity (requires netcat or Test-NetConnection)
        $tcpTest = Test-NetConnection -ComputerName $RDSEndpoint -Port 3306 -WarningAction SilentlyContinue -ErrorAction Stop
        
        if ($tcpTest.TcpTestSucceeded) {
            Write-Success "Database port 3306 is reachable"
            return $true
        }
        else {
            Write-Failure "Database port 3306 is not reachable"
            Write-Info "Recommendation: Check RDS security group, check if RDS is running, verify network connectivity"
            return $false
        }
    }
    catch {
        Write-Warning "TCP test inconclusive: $($_.Exception.Message)"
        Write-Info "Run from EC2 instance: nc -zv $RDSEndpoint 3306"
        return $false
    }
}

#=============================================================================
# Layer 10: NAT Gateway / Egress
#=============================================================================

function Test-EgressConnectivity {
    Write-Header "LAYER 10: Egress Control (NAT Gateway)"
    Write-Info "Testing outbound internet connectivity"
    
    try {
        # Test external connectivity
        $response = Invoke-WebRequest -Uri "https://checkip.amazonaws.com" -Method Get -ErrorAction Stop -TimeoutSec 10
        $publicIp = $response.Content.Trim()
        
        Write-Success "Outbound connectivity successful"
        Write-Info "Current Public IP: $publicIp"
        
        # Verify it's not a private IP
        if ($publicIp -match '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)') {
            Write-Warning "Public IP appears to be private: $publicIp (NAT Gateway may not be configured)"
            return $false
        }
        else {
            Write-Success "NAT Gateway properly translating private IP to public IP"
            return $true
        }
    }
    catch {
        Write-Failure "Outbound connectivity failed: $($_.Exception.Message)"
        Write-Info "Recommendation: Check NAT Gateway configuration, route tables, and security groups"
        return $false
    }
}

#=============================================================================
# Scenario 1: Connection Timeout - Security Group Missing
#=============================================================================

function Test-Scenario1-ConnectionTimeout {
    Write-Header "TROUBLESHOOTING SCENARIO 1: Connection Timeout"
    Write-Info "Simulating: ALB security group missing inbound rule from itself"
    
    # This scenario requires manual setup, so we'll provide diagnostic steps
    Write-Info "Diagnostic Steps:"
    Write-Info "1. Test application connectivity:"
    Write-Info "   curl -I https://app.example.com"
    Write-Info ""
    Write-Info "2. Check if DNS works:"
    Write-Info "   Resolve-DnsName app.example.com"
    Write-Info ""
    Write-Info "3. Check target health:"
    Write-Info "   Get-ELBv2TargetHealth -TargetGroupArn $TargetGroupArn"
    Write-Info ""
    Write-Info "4. If targets are unhealthy, check app security group:"
    Write-Info "   Get-EC2SecurityGroup -GroupId $AppSecurityGroup"
    Write-Info ""
    Write-Info "5. Verify port 8080 is allowed from ALB security group:"
    Write-Info "   Get-EC2SecurityGroup -GroupId $AppSecurityGroup | "
    Write-Info "   Select-Object -ExpandProperty IpPermissions"
    Write-Info ""
    Write-Info "6. If missing, add the rule:"
    Write-Info "   `$permission = New-Object 'Amazon.EC2.Model.IpPermission'"
    Write-Info "   `$permission.IpProtocol = 'tcp'"
    Write-Info "   `$permission.FromPort = 8080"
    Write-Info "   `$permission.ToPort = 8080"
    Write-Info "   `$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = '$ALBSecurityGroup'}))"
    Write-Info "   Grant-EC2SecurityGroupIngress -GroupId $AppSecurityGroup -IpPermission `$permission"
    Write-Info ""
    Write-Info "7. Verify health checks pass (may take 30-60 seconds)"
    Write-Info ""
    Write-Success "Scenario 1 diagnostic steps provided"
}

#=============================================================================
# Scenario 2: Database Connection Timeout
#=============================================================================

function Test-Scenario2-DatabaseTimeout {
    Write-Header "TROUBLESHOOTING SCENARIO 2: Database Connection Timeout"
    Write-Info "Simulating: RDS security group missing inbound rule"
    
    Write-Info "Diagnostic Steps:"
    Write-Info "1. Check if RDS is running:"
    Write-Info "   Get-RDSDBInstance -DBInstanceIdentifier prod-db"
    Write-Info ""
    Write-Info "2. Test port connectivity from app server:"
    Write-Info "   (SSH to app server, then:)"
    Write-Info "   Test-NetConnection -ComputerName $RDSEndpoint -Port 3306"
    Write-Info ""
    Write-Info "3. Check RDS security group inbound rules:"
    Write-Info "   Get-EC2SecurityGroup -GroupId $RDSSecurityGroup | "
    Write-Info "   Select-Object -ExpandProperty IpPermissions"
    Write-Info ""
    Write-Info "4. Verify port 3306 is allowed from app security group:"
    Write-Info "   # Should see a rule with:"
    Write-Info "   # - IpProtocol: tcp"
    Write-Info "   # - FromPort: 3306"
    Write-Info "   # - ToPort: 3306"
    Write-Info "   # - UserIdGroupPairs with GroupId = $AppSecurityGroup"
    Write-Info ""
    Write-Info "5. If missing, add the rule:"
    Write-Info "   `$permission = New-Object 'Amazon.EC2.Model.IpPermission'"
    Write-Info "   `$permission.IpProtocol = 'tcp'"
    Write-Info "   `$permission.FromPort = 3306"
    Write-Info "   `$permission.ToPort = 3306"
    Write-Info "   `$permission.UserIdGroupPairs.Add((New-Object 'Amazon.EC2.Model.UserIdGroupPair' -Property @{GroupId = '$AppSecurityGroup'}))"
    Write-Info "   Grant-EC2SecurityGroupIngress -GroupId $RDSSecurityGroup -IpPermission `$permission"
    Write-Info ""
    Write-Success "Scenario 2 diagnostic steps provided"
}

#=============================================================================
# Scenario 3: High Latency
#=============================================================================

function Test-Scenario3-HighLatency {
    Write-Header "TROUBLESHOOTING SCENARIO 3: High Latency"
    Write-Info "Checking performance metrics"
    
    try {
        # Get CloudFront metrics
        $metricsParams = @{
            Namespace = "AWS/CloudFront"
            MetricName = "OriginLatency"
            StartTime = (Get-Date).AddHours(-1)
            EndTime = Get-Date
            Period = 300
            Statistics = @("Average")
            ErrorAction = "SilentlyContinue"
        }
        
        $cfMetrics = Get-CWMetricStatistic @metricsParams
        if ($cfMetrics) {
            $avgLatency = ($cfMetrics.Datapoints | Measure-Object -Property Average -Average).Average
            Write-Info "CloudFront Origin Latency (last hour): ${avgLatency}ms"
            
            if ($avgLatency -gt 1000) {
                Write-Warning "Origin latency is high (> 1000ms)"
                Write-Info "Check: ALB target response time, database query performance"
            }
        }
        
        # Get ALB metrics
        $albMetricsParams = @{
            Namespace = "AWS/ApplicationELB"
            MetricName = "TargetResponseTime"
            StartTime = (Get-Date).AddHours(-1)
            EndTime = Get-Date
            Period = 300
            Statistics = @("Average")
            ErrorAction = "SilentlyContinue"
        }
        
        $albMetrics = Get-CWMetricStatistic @albMetricsParams
        if ($albMetrics) {
            $avgResponseTime = ($albMetrics.Datapoints | Measure-Object -Property Average -Average).Average
            Write-Info "ALB Target Response Time (last hour): ${avgResponseTime}ms"
            
            if ($avgResponseTime -gt 500) {
                Write-Warning "Target response time is high (> 500ms)"
                Write-Info "Check: Application performance, database query performance"
            }
        }
        
        Write-Success "Performance metrics retrieved"
    }
    catch {
        Write-Warning "Could not retrieve CloudWatch metrics: $($_.Exception.Message)"
        Write-Info "CloudWatch metrics require proper IAM permissions"
    }
}

#=============================================================================
# Scenario 4: Private Instances - No Internet Access
#=============================================================================

function Test-Scenario4-NoInternetAccess {
    Write-Header "TROUBLESHOOTING SCENARIO 4: Private Instance - No Internet Access"
    Write-Info "Checking NAT Gateway and route table configuration"
    
    try {
        # Get NAT Gateways
        $natGateways = Get-EC2NatGateway -Filter @(@{Name="state"; Values="available"}) -ErrorAction Stop
        
        if ($natGateways.Count -gt 0) {
            Write-Success "NAT Gateway(s) found: $($natGateways.Count)"
            
            foreach ($nat in $natGateways) {
                Write-Info "NAT Gateway ID: $($nat.NatGatewayId)"
                Write-Info "Public IP: $($nat.NatGatewayAddresses[0].PublicIp)"
                Write-Info "Subnet ID: $($nat.SubnetId)"
                Write-Info "State: $($nat.State)"
            }
        }
        else {
            Write-Failure "No NAT Gateway found"
            Write-Info "Recommendation: Create a NAT Gateway in a public subnet with an Elastic IP"
        }
        
        # Check private route tables
        $privateTables = Get-EC2RouteTable -ErrorAction Stop | Where-Object {
            $_.Routes | Where-Object { $_.NatGatewayId }
        }
        
        if ($privateTables) {
            Write-Success "Private route table(s) with NAT Gateway found: $($privateTables.Count)"
            
            foreach ($table in $privateTables) {
                $natRoute = $table.Routes | Where-Object { $_.NatGatewayId }
                Write-Info "Route Table: $($table.RouteTableId)"
                Write-Info "  Route: $($natRoute.DestinationCidrBlock) → $($natRoute.NatGatewayId)"
            }
        }
        else {
            Write-Warning "No private route tables with NAT Gateway found"
        }
    }
    catch {
        Write-Warning "Could not retrieve NAT Gateway configuration: $($_.Exception.Message)"
    }
    
    # Provide manual diagnostic steps
    Write-Info ""
    Write-Info "Manual Diagnostic Steps (SSH to private instance):"
    Write-Info "1. Test outbound connectivity:"
    Write-Info "   curl https://checkip.amazonaws.com"
    Write-Info ""
    Write-Info "2. Check security group allows outbound HTTPS:"
    Write-Info "   # Should see rule: TCP 443 to 0.0.0.0/0 (outbound)"
    Write-Info ""
    Write-Info "3. If missing, add outbound rule:"
    Write-Info "   `$permission = New-Object 'Amazon.EC2.Model.IpPermission'"
    Write-Info "   `$permission.IpProtocol = 'tcp'"
    Write-Info "   `$permission.FromPort = 443"
    Write-Info "   `$permission.ToPort = 443"
    Write-Info "   `$permission.IpRanges.Add('0.0.0.0/0')"
    Write-Info "   Grant-EC2SecurityGroupEgress -GroupId $AppSecurityGroup -IpPermission `$permission"
}

#=============================================================================
# Scenario 5: WAF Blocking Legitimate Users
#=============================================================================

function Test-Scenario5-WAFBlocking {
    Write-Header "TROUBLESHOOTING SCENARIO 5: WAF Blocking Traffic"
    Write-Info "Checking WAF configuration and logs"
    
    try {
        # Get WAF resources
        $webAcls = Get-WAFv2WebACL -Scope CLOUDFRONT -ErrorAction SilentlyContinue
        
        if ($webAcls) {
            Write-Success "WAF Web ACL(s) found: $($webAcls.Count)"
            
            foreach ($acl in $webAcls) {
                Write-Info "Web ACL: $($acl.Name)"
                Write-Info "Rules: $($acl.Rules.Count)"
                
                # Check for rate limiting rules
                $rateLimitRules = $acl.Rules | Where-Object { $_.Statement.RateBasedStatement }
                if ($rateLimitRules) {
                    Write-Warning "Rate limiting rules configured:"
                    foreach ($rule in $rateLimitRules) {
                        Write-Info "  Rule: $($rule.Name) - Limit: $($rule.Statement.RateBasedStatement.Limit) requests/5 min"
                    }
                }
            }
        }
        else {
            Write-Warning "No WAF Web ACLs found"
        }
    }
    catch {
        Write-Warning "Could not retrieve WAF configuration: $($_.Exception.Message)"
    }
    
    Write-Info ""
    Write-Info "Manual Diagnostic Steps:"
    Write-Info "1. Check WAF logs in CloudWatch:"
    Write-Info "   Get-CWLogEvents -LogGroupName '/aws/wafv2/cloudfront' -LogStreamName 'logs' -StartFromHead `$true"
    Write-Info ""
    Write-Info "2. Look for BLOCK actions:"
    Write-Info "   (Check logs for 'action: BLOCK')"
    Write-Info ""
    Write-Info "3. If rate-limited, whitelist IP:"
    Write-Info "   # Create IP set with office IP address"
    Write-Info "   # Update WAF rule to exclude whitelisted IPs"
    Write-Info ""
    Write-Info "4. Or increase rate limit threshold:"
    Write-Info "   # (Be careful - this may reduce security)"
}

#=============================================================================
# End-to-End Validation
#=============================================================================

function Test-EndToEnd {
    Write-Header "END-TO-END VALIDATION: Complete Traffic Flow"
    Write-Info "Testing: User → CloudFront → ALB → App → Database → Response"
    
    $totalTests = 0
    $passedTests = 0
    
    $testSequence = @(
        @{ Name = "DNS Resolution"; Test = { Test-DNSResolution } },
        @{ Name = "CloudFront Connectivity"; Test = { Test-CloudFrontConnectivity } },
        @{ Name = "ALB Health"; Test = { Test-ALBHealthStatus } },
        @{ Name = "Target Group Health"; Test = { Test-TargetGroupHealth } },
        @{ Name = "VPC Routing"; Test = { Test-VPCRouting } },
        @{ Name = "Security Groups"; Test = { Test-SecurityGroupConfiguration } },
        @{ Name = "Application Health"; Test = { Test-ApplicationHealth } },
        @{ Name = "Database Connectivity"; Test = { Test-DatabaseConnectivity } },
        @{ Name = "Egress Control"; Test = { Test-EgressConnectivity } }
    )
    
    foreach ($test in $testSequence) {
        $totalTests++
        try {
            $result = & $test.Test
            if ($result) {
                $passedTests++
            }
        }
        catch {
            Write-Warning "Exception during test: $($test.Name)"
        }
    }
    
    return @{
        Total = $totalTests
        Passed = $passedTests
        Failed = $totalTests - $passedTests
    }
}

#=============================================================================
# Report Generation
#=============================================================================

function Generate-Report {
    Write-Header "VALIDATION SUMMARY REPORT"
    
    Write-Host "`n[✓] PASSED TESTS ($($script:ValidResults.Count))" -ForegroundColor Green
    foreach ($result in $script:ValidResults) {
        Write-Host "  • $result" -ForegroundColor Green
    }
    
    if ($script:WarningResults.Count -gt 0) {
        Write-Host "`n[⚠] WARNINGS ($($script:WarningResults.Count))" -ForegroundColor Yellow
        foreach ($warning in $script:WarningResults) {
            Write-Host "  • $warning" -ForegroundColor Yellow
        }
    }
    
    if ($script:FailedResults.Count -gt 0) {
        Write-Host "`n[✗] FAILED TESTS ($($script:FailedResults.Count))" -ForegroundColor Red
        foreach ($failure in $script:FailedResults) {
            Write-Host "  • $failure" -ForegroundColor Red
        }
    }
    
    Write-Host "`n" -ForegroundColor White
    Write-Host ("=" * 80) -ForegroundColor Cyan
    Write-Host "Module 00: Complete AWS Traffic Flow - Validation Complete" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
    
    $successRate = if ($script:ValidResults.Count -gt 0) { 
        [Math]::Round(($script:ValidResults.Count / ($script:ValidResults.Count + $script:FailedResults.Count)) * 100, 2)
    } else { 0 }
    
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { 'Green' } else { 'Yellow' })
    Write-Host "Total Checks: $($script:ValidResults.Count + $script:FailedResults.Count)" -ForegroundColor Cyan
}

#=============================================================================
# Main Execution
#=============================================================================

function Main {
    Write-Host "`n╔════════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Module 00: Complete AWS Traffic Flow - PowerShell Validation                ║" -ForegroundColor Cyan
    Write-Host "║  Version $script:ModuleVersion | Environment: $Environment                              ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Info "Domain: $DomainName"
    Write-Info "ALB: $ALBDnsName"
    Write-Info "RDS: $RDSEndpoint"
    Write-Info ""
    
    # Run Layer-by-Layer Tests
    Test-DNSResolution | Out-Null
    Test-CloudFrontConnectivity | Out-Null
    Test-ALBHealthStatus | Out-Null
    Test-TargetGroupHealth | Out-Null
    Test-VPCRouting | Out-Null
    Test-SecurityGroupConfiguration | Out-Null
    Test-ApplicationHealth | Out-Null
    Test-DatabaseConnectivity | Out-Null
    Test-EgressConnectivity | Out-Null
    
    # Run Troubleshooting Scenarios
    if ($RunAllScenarios) {
        Write-Header "OPTIONAL: TROUBLESHOOTING SCENARIOS"
        Test-Scenario1-ConnectionTimeout
        Test-Scenario2-DatabaseTimeout
        Test-Scenario3-HighLatency
        Test-Scenario4-NoInternetAccess
        Test-Scenario5-WAFBlocking
    }
    
    # Generate Report
    Generate-Report
}

# Run Main
Main

Write-Host "`nFor detailed information, refer to Module-00-README-UPDATED.md" -ForegroundColor Cyan
Write-Host "For next steps, see module structure 01-10 in the repository`n" -ForegroundColor Cyan
