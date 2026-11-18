############################################
# Regional Transit Gateway: Direct Connect on-ramp, peered to Cloud WAN
############################################

resource "aws_ec2_transit_gateway" "this" {
  description                     = "DX on-ramp ${var.name}"
  amazon_side_asn                 = var.tgw_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = { Name = "tgw-${var.name}" }
}

resource "aws_ec2_transit_gateway_route_table" "dx" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "tgw-${var.name}-dx" }
}

resource "aws_ec2_transit_gateway_policy_table" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  tags               = { Name = "tgw-${var.name}-policy" }
}

# TGW <-> Cloud WAN core network edge in this region
resource "aws_networkmanager_transit_gateway_peering" "this" {
  core_network_id     = var.core_network_id
  transit_gateway_arn = aws_ec2_transit_gateway.this.arn
}

resource "aws_ec2_transit_gateway_policy_table_association" "this" {
  transit_gateway_attachment_id  = aws_networkmanager_transit_gateway_peering.this.transit_gateway_attachment_id
  transit_gateway_policy_table_id = aws_ec2_transit_gateway_policy_table.this.id
}

# Attach the DX route table to the Cloud WAN "onprem" segment
resource "aws_networkmanager_transit_gateway_route_table_attachment" "onprem" {
  peering_id                      = aws_networkmanager_transit_gateway_peering.this.id
  transit_gateway_route_table_arn = aws_ec2_transit_gateway_route_table.dx.arn

  tags = {
    Name    = "tgw-${var.name}-onprem"
    segment = "onprem"
  }

  depends_on = [aws_ec2_transit_gateway_policy_table_association.this]
}

# Direct Connect gateway -> this TGW. Advertise only the environment /16s to on-premises.
resource "aws_dx_gateway_association" "this" {
  dx_gateway_id         = var.dx_gateway_id
  associated_gateway_id = aws_ec2_transit_gateway.this.id
  allowed_prefixes      = var.dx_allowed_prefixes
}

data "aws_ec2_transit_gateway_dx_gateway_attachment" "this" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  dx_gateway_id      = var.dx_gateway_id

  depends_on = [aws_dx_gateway_association.this]
}

resource "aws_ec2_transit_gateway_route_table_association" "dx" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dx.id
}

# Learn on-premises prefixes (172.16.0.0/12) from the DX attachment
resource "aws_ec2_transit_gateway_route_table_propagation" "dx" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.dx.id
}

############################################
# RAM: share regional IPAM pools and the Resolver rule with the organization
############################################

locals {
  ram_resources = merge(var.shared_resource_arns, {
    "resolver-rule" = aws_route53_resolver_rule.onprem.arn
  })
}

resource "aws_ram_resource_share" "this" {
  name                      = "network-${var.name}"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "this" {
  for_each           = local.ram_resources
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.this.arn
}

resource "aws_ram_principal_association" "this" {
  for_each           = toset(var.ram_principals)
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.this.arn
}
