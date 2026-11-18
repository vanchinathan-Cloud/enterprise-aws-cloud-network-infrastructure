############################################
# Regional hubs: inspection VPC + Network Firewall (+ optional GWLB),
# DNS VPC with Route 53 Resolver, TGW for Direct Connect, RAM shares.
############################################

locals {
  hub_common = {
    core_network_id        = aws_networkmanager_core_network.this.id
    core_network_arn       = aws_networkmanager_core_network.this.arn
    dx_gateway_id          = aws_dx_gateway.this.id
    dx_allowed_prefixes    = local.dx_allowed_prefixes
    environment_cidrs      = var.environment_cidrs
    onprem_cidrs           = var.onprem_cidrs
    vpn_cidrs              = var.vpn_cidrs
    onprem_domain          = var.onprem_domain
    onprem_dns_ips         = var.onprem_dns_ips
    egress_allowed_domains = var.egress_allowed_domains
    ram_principals         = var.ram_principals
    enable_gwlb            = var.enable_gwlb
  }

  # Regional IPAM pools that are shared out through RAM, keyed by region
  shared_pool_arns = {
    for region in local.region_names : region => {
      for k, p in local.regional_pools :
      "pool-${p.env}" => aws_vpc_ipam_pool.regional[k].arn
      if p.region == region
    }
  }
}

module "hub_mumbai" {
  source    = "./modules/regional-hub"
  providers = { aws = aws.mumbai }

  name                   = var.regions["ap-south-1"].name
  azs                    = var.regions["ap-south-1"].azs
  tgw_asn                = var.regions["ap-south-1"].tgw_asn
  hub_ipam_pool_id       = aws_vpc_ipam_pool.regional["shared-ap-south-1"].id
  shared_resource_arns   = local.shared_pool_arns["ap-south-1"]
  core_network_id        = local.hub_common.core_network_id
  core_network_arn       = local.hub_common.core_network_arn
  dx_gateway_id          = local.hub_common.dx_gateway_id
  dx_allowed_prefixes    = local.hub_common.dx_allowed_prefixes
  environment_cidrs      = local.hub_common.environment_cidrs
  onprem_cidrs           = local.hub_common.onprem_cidrs
  vpn_cidrs              = local.hub_common.vpn_cidrs
  onprem_domain          = local.hub_common.onprem_domain
  onprem_dns_ips         = local.hub_common.onprem_dns_ips
  egress_allowed_domains = local.hub_common.egress_allowed_domains
  ram_principals         = local.hub_common.ram_principals
  enable_gwlb            = local.hub_common.enable_gwlb

  depends_on = [
    aws_networkmanager_core_network_policy_attachment.this,
    aws_vpc_ipam_pool_cidr.regional,
  ]
}

module "hub_dubai" {
  source    = "./modules/regional-hub"
  providers = { aws = aws.dubai }

  name                   = var.regions["me-central-1"].name
  azs                    = var.regions["me-central-1"].azs
  tgw_asn                = var.regions["me-central-1"].tgw_asn
  hub_ipam_pool_id       = aws_vpc_ipam_pool.regional["shared-me-central-1"].id
  shared_resource_arns   = local.shared_pool_arns["me-central-1"]
  core_network_id        = local.hub_common.core_network_id
  core_network_arn       = local.hub_common.core_network_arn
  dx_gateway_id          = local.hub_common.dx_gateway_id
  dx_allowed_prefixes    = local.hub_common.dx_allowed_prefixes
  environment_cidrs      = local.hub_common.environment_cidrs
  onprem_cidrs           = local.hub_common.onprem_cidrs
  vpn_cidrs              = local.hub_common.vpn_cidrs
  onprem_domain          = local.hub_common.onprem_domain
  onprem_dns_ips         = local.hub_common.onprem_dns_ips
  egress_allowed_domains = local.hub_common.egress_allowed_domains
  ram_principals         = local.hub_common.ram_principals
  enable_gwlb            = local.hub_common.enable_gwlb

  depends_on = [
    aws_networkmanager_core_network_policy_attachment.this,
    aws_vpc_ipam_pool_cidr.regional,
  ]
}

module "hub_eu" {
  source    = "./modules/regional-hub"
  providers = { aws = aws.frankfurt }

  name                   = var.regions["eu-central-1"].name
  azs                    = var.regions["eu-central-1"].azs
  tgw_asn                = var.regions["eu-central-1"].tgw_asn
  hub_ipam_pool_id       = aws_vpc_ipam_pool.regional["shared-eu-central-1"].id
  shared_resource_arns   = local.shared_pool_arns["eu-central-1"]
  core_network_id        = local.hub_common.core_network_id
  core_network_arn       = local.hub_common.core_network_arn
  dx_gateway_id          = local.hub_common.dx_gateway_id
  dx_allowed_prefixes    = local.hub_common.dx_allowed_prefixes
  environment_cidrs      = local.hub_common.environment_cidrs
  onprem_cidrs           = local.hub_common.onprem_cidrs
  vpn_cidrs              = local.hub_common.vpn_cidrs
  onprem_domain          = local.hub_common.onprem_domain
  onprem_dns_ips         = local.hub_common.onprem_dns_ips
  egress_allowed_domains = local.hub_common.egress_allowed_domains
  ram_principals         = local.hub_common.ram_principals
  enable_gwlb            = local.hub_common.enable_gwlb

  depends_on = [
    aws_networkmanager_core_network_policy_attachment.this,
    aws_vpc_ipam_pool_cidr.regional,
  ]
}
