############################################
# DNS hub VPC (segment: shared) with Route 53 Resolver endpoints
############################################

resource "aws_vpc" "dns" {
  ipv4_ipam_pool_id   = var.hub_ipam_pool_id
  ipv4_netmask_length = 26

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "dns-hub-${var.name}" }
}

resource "aws_subnet" "dns" {
  for_each          = local.az_index
  vpc_id            = aws_vpc.dns.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.dns.cidr_block, 1, each.value)
  tags              = { Name = "dns-hub-${var.name}-${each.key}" }
}

resource "aws_networkmanager_vpc_attachment" "dns" {
  core_network_id = var.core_network_id
  vpc_arn         = aws_vpc.dns.arn
  subnet_arns     = [for s in aws_subnet.dns : s.arn]

  tags = {
    Name    = "dns-hub-${var.name}"
    segment = "shared"
  }
}

# The shared segment requires acceptance; the hub accepts its own attachment.
resource "aws_networkmanager_attachment_accepter" "dns" {
  attachment_id   = aws_networkmanager_vpc_attachment.dns.id
  attachment_type = aws_networkmanager_vpc_attachment.dns.attachment_type
}

resource "aws_route" "dns_internal" {
  for_each               = toset(local.internal_all)
  route_table_id         = aws_vpc.dns.main_route_table_id
  destination_cidr_block = each.value
  core_network_arn       = var.core_network_arn

  depends_on = [aws_networkmanager_attachment_accepter.dns]
}

resource "aws_security_group" "resolver" {
  name_prefix = "resolver-${var.name}-"
  description = "Route 53 Resolver endpoints"
  vpc_id      = aws_vpc.dns.id

  ingress {
    description = "DNS (UDP) from on-premises, VPN and AWS"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = local.internal_all
  }

  ingress {
    description = "DNS (TCP) from on-premises, VPN and AWS"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = local.internal_all
  }

  egress {
    description = "DNS (UDP) to on-premises and AWS"
    protocol    = "udp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = local.internal_all
  }

  egress {
    description = "DNS (TCP) to on-premises and AWS"
    protocol    = "tcp"
    from_port   = 53
    to_port     = 53
    cidr_blocks = local.internal_all
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  name               = "inbound-${var.name}"
  direction          = "INBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = aws_subnet.dns
    content {
      subnet_id = ip_address.value.id
    }
  }
}

resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "outbound-${var.name}"
  direction          = "OUTBOUND"
  security_group_ids = [aws_security_group.resolver.id]

  dynamic "ip_address" {
    for_each = aws_subnet.dns
    content {
      subnet_id = ip_address.value.id
    }
  }
}

resource "aws_route53_resolver_rule" "onprem" {
  name                 = "forward-${replace(var.onprem_domain, ".", "-")}-${var.name}"
  domain_name          = var.onprem_domain
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id

  dynamic "target_ip" {
    for_each = toset(var.onprem_dns_ips)
    content {
      ip   = target_ip.value
      port = 53
    }
  }
}

resource "aws_route53_resolver_rule_association" "dns_hub" {
  resolver_rule_id = aws_route53_resolver_rule.onprem.id
  vpc_id           = aws_vpc.dns.id
}
