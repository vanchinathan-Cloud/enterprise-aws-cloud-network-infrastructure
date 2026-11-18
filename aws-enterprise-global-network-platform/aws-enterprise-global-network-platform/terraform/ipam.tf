############################################
# IPAM: top pool -> environment pools -> regional pools
############################################

resource "aws_vpc_ipam" "this" {
  description = "Global IPAM for the airline network"

  dynamic "operating_regions" {
    for_each = local.region_names
    content {
      region_name = operating_regions.value
    }
  }
}

resource "aws_vpc_ipam_pool" "top" {
  description    = "Top-level pool (all AWS environments)"
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
}

resource "aws_vpc_ipam_pool_cidr" "top" {
  for_each     = var.environment_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.top.id
  cidr         = each.value
}

# One pool per environment (no locale), carved from the top pool
resource "aws_vpc_ipam_pool" "env" {
  for_each            = var.environment_cidrs
  description         = "${each.key} environment"
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.top.id
}

resource "aws_vpc_ipam_pool_cidr" "env" {
  for_each     = var.environment_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.env[each.key].id
  cidr         = each.value

  depends_on = [aws_vpc_ipam_pool_cidr.top]
}

# Regional pools: locale restricts allocation to VPCs in that region
resource "aws_vpc_ipam_pool" "regional" {
  for_each                          = local.regional_pools
  description                       = "${each.value.env} - ${each.value.region}"
  address_family                    = "ipv4"
  ipam_scope_id                     = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id               = aws_vpc_ipam_pool.env[each.value.env].id
  locale                            = each.value.region
  auto_import                       = false
  allocation_min_netmask_length     = 22 # largest VPC allowed (/22)
  allocation_max_netmask_length     = 26 # smallest VPC allowed (/26)
  allocation_default_netmask_length = 24

  allocation_resource_tags = {
    Environment = each.value.env
  }
}

resource "aws_vpc_ipam_pool_cidr" "regional" {
  for_each     = local.regional_pools
  ipam_pool_id = aws_vpc_ipam_pool.regional[each.key].id
  cidr         = each.value.cidr

  depends_on = [aws_vpc_ipam_pool_cidr.env]
}

############################################
# Reserved ranges: on-premises (DX) and VPN
# Allocated in full so IPAM flags overlaps and nothing can draw from them.
############################################

resource "aws_vpc_ipam_pool" "reserved" {
  description    = "Reserved non-AWS ranges (on-premises via DX, VPN)"
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
}

resource "aws_vpc_ipam_pool_cidr" "reserved" {
  for_each     = local.reserved_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.reserved.id
  cidr         = each.value
}

resource "aws_vpc_ipam_pool_cidr_allocation" "reserved" {
  for_each     = local.reserved_cidrs
  ipam_pool_id = aws_vpc_ipam_pool.reserved.id
  cidr         = each.value
  description  = contains(var.onprem_cidrs, each.value) ? "On-premises via Direct Connect" : "VPN"

  depends_on = [aws_vpc_ipam_pool_cidr.reserved]
}
