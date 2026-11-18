############################################
# Inspection VPC: Cloud WAN attachment -> Network Firewall -> NAT/IGW
############################################

locals {
  az_index = { for i, az in var.azs : az => i }
  n_az     = length(var.azs)

  aws_cidrs     = values(var.environment_cidrs)
  internal_all  = concat(local.aws_cidrs, var.onprem_cidrs, var.vpn_cidrs)
  internal_pairs = {
    for pair in setproduct(var.azs, local.internal_all) :
    "${pair[0]}|${pair[1]}" => { az = pair[0], cidr = pair[1] }
  }
}

resource "aws_vpc" "inspection" {
  ipv4_ipam_pool_id   = var.hub_ipam_pool_id
  ipv4_netmask_length = 24

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "inspection-${var.name}" }
}

# /24 split into /28s: attach [0..n), firewall [n..2n), nat [2n..3n), gwlb [3n..4n)
resource "aws_subnet" "attach" {
  for_each          = local.az_index
  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.inspection.cidr_block, 4, each.value)
  tags              = { Name = "inspection-${var.name}-attach-${each.key}" }
}

resource "aws_subnet" "firewall" {
  for_each          = local.az_index
  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.inspection.cidr_block, 4, local.n_az + each.value)
  tags              = { Name = "inspection-${var.name}-firewall-${each.key}" }
}

resource "aws_subnet" "nat" {
  for_each          = local.az_index
  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.inspection.cidr_block, 4, 2 * local.n_az + each.value)
  tags              = { Name = "inspection-${var.name}-nat-${each.key}" }
}

resource "aws_subnet" "gwlb" {
  for_each          = var.enable_gwlb ? local.az_index : {}
  vpc_id            = aws_vpc.inspection.id
  availability_zone = each.key
  cidr_block        = cidrsubnet(aws_vpc.inspection.cidr_block, 4, 3 * local.n_az + each.value)
  tags              = { Name = "inspection-${var.name}-gwlb-${each.key}" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.inspection.id
  tags   = { Name = "inspection-${var.name}" }
}

resource "aws_eip" "nat" {
  for_each = local.az_index
  domain   = "vpc"
  tags     = { Name = "inspection-${var.name}-nat-${each.key}" }
}

resource "aws_nat_gateway" "this" {
  for_each      = local.az_index
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.nat[each.key].id
  tags          = { Name = "inspection-${var.name}-${each.key}" }

  depends_on = [aws_internet_gateway.this]
}

# Cloud WAN attachment. appliance_mode keeps both directions of a flow in one AZ.
resource "aws_networkmanager_vpc_attachment" "inspection" {
  core_network_id = var.core_network_id
  vpc_arn         = aws_vpc.inspection.arn
  subnet_arns     = [for s in aws_subnet.attach : s.arn]

  options {
    appliance_mode_support = true
  }

  tags = {
    Name = "inspection-${var.name}"
    nfg  = "inspection" # joins the "inspection" network function group
  }
}

############################################
# Routing
############################################

# Attachment subnets: everything goes to the firewall endpoint in the same AZ
resource "aws_route_table" "attach" {
  for_each = local.az_index
  vpc_id   = aws_vpc.inspection.id
  tags     = { Name = "inspection-${var.name}-attach-${each.key}" }
}

resource "aws_route_table_association" "attach" {
  for_each       = local.az_index
  subnet_id      = aws_subnet.attach[each.key].id
  route_table_id = aws_route_table.attach[each.key].id
}

resource "aws_route" "attach_default" {
  for_each               = local.az_index
  route_table_id         = aws_route_table.attach[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.fw_endpoints[each.key]
}

# Firewall subnets: internal destinations back to Cloud WAN, internet via NAT
resource "aws_route_table" "firewall" {
  for_each = local.az_index
  vpc_id   = aws_vpc.inspection.id
  tags     = { Name = "inspection-${var.name}-firewall-${each.key}" }
}

resource "aws_route_table_association" "firewall" {
  for_each       = local.az_index
  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall[each.key].id
}

resource "aws_route" "firewall_internal" {
  for_each               = local.internal_pairs
  route_table_id         = aws_route_table.firewall[each.value.az].id
  destination_cidr_block = each.value.cidr
  core_network_arn       = var.core_network_arn

  depends_on = [aws_networkmanager_vpc_attachment.inspection]
}

resource "aws_route" "firewall_internet" {
  for_each               = local.az_index
  route_table_id         = aws_route_table.firewall[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# NAT subnets: internet via IGW, return traffic back through the firewall
resource "aws_route_table" "nat" {
  for_each = local.az_index
  vpc_id   = aws_vpc.inspection.id
  tags     = { Name = "inspection-${var.name}-nat-${each.key}" }
}

resource "aws_route_table_association" "nat" {
  for_each       = local.az_index
  subnet_id      = aws_subnet.nat[each.key].id
  route_table_id = aws_route_table.nat[each.key].id
}

resource "aws_route" "nat_default" {
  for_each               = local.az_index
  route_table_id         = aws_route_table.nat[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "nat_return" {
  for_each               = local.internal_pairs
  route_table_id         = aws_route_table.nat[each.value.az].id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = local.fw_endpoints[each.value.az]
}

############################################
# Optional Gateway Load Balancer for third-party appliances
############################################

resource "aws_lb" "gwlb" {
  count                            = var.enable_gwlb ? 1 : 0
  name                             = "gwlb-${var.name}"
  load_balancer_type               = "gateway"
  subnets                          = [for s in aws_subnet.gwlb : s.id]
  enable_cross_zone_load_balancing = false
}

resource "aws_lb_target_group" "gwlb" {
  count    = var.enable_gwlb ? 1 : 0
  name     = "gwlb-${var.name}"
  port     = 6081
  protocol = "GENEVE"
  vpc_id   = aws_vpc.inspection.id

  health_check {
    protocol = "TCP"
    port     = 80
  }
}

resource "aws_lb_listener" "gwlb" {
  count             = var.enable_gwlb ? 1 : 0
  load_balancer_arn = aws_lb.gwlb[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gwlb[0].arn
  }
}

resource "aws_vpc_endpoint_service" "gwlb" {
  count                      = var.enable_gwlb ? 1 : 0
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb[0].arn]
}
