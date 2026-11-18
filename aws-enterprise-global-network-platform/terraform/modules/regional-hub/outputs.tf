output "summary" {
  value = {
    inspection_vpc_id     = aws_vpc.inspection.id
    inspection_vpc_cidr   = aws_vpc.inspection.cidr_block
    dns_vpc_id            = aws_vpc.dns.id
    dns_vpc_cidr          = aws_vpc.dns.cidr_block
    firewall_arn          = aws_networkfirewall_firewall.this.arn
    transit_gateway_id    = aws_ec2_transit_gateway.this.id
    resolver_rule_arn     = aws_route53_resolver_rule.onprem.arn
    inbound_endpoint_id   = aws_route53_resolver_endpoint.inbound.id
    gwlb_endpoint_service = var.enable_gwlb ? aws_vpc_endpoint_service.gwlb[0].service_name : null
  }
}
