output "ipam_id" {
  value = aws_vpc_ipam.this.id
}

output "ipam_regional_pool_ids" {
  description = "IPAM pool IDs per environment-region, used by AFT to allocate VPC CIDRs"
  value       = { for k, p in aws_vpc_ipam_pool.regional : k => p.id }
}

output "core_network_id" {
  value = aws_networkmanager_core_network.this.id
}

output "core_network_arn" {
  value = aws_networkmanager_core_network.this.arn
}

output "dx_gateway_id" {
  value = aws_dx_gateway.this.id
}

output "hubs" {
  value = {
    mumbai = module.hub_mumbai.summary
    dubai  = module.hub_dubai.summary
    eu     = module.hub_eu.summary
  }
}
