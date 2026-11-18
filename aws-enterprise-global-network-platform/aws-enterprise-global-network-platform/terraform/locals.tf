locals {
  region_names = keys(var.regions)

  # One regional pool per environment and region, e.g. "production-ap-south-1" = 10.10.0.0/18
  regional_pools = {
    for item in flatten([
      for env, cidr in var.environment_cidrs : [
        for region, cfg in var.regions : {
          key    = "${env}-${region}"
          env    = env
          region = region
          cidr   = cidrsubnet(cidr, 2, cfg.slot)
        }
      ]
    ]) : item.key => item
  }

  reserved_cidrs = {
    for c in concat(var.onprem_cidrs, var.vpn_cidrs) : c => c
  }

  # Cloud WAN segments and their attachment-acceptance setting
  segment_acceptance = {
    prod     = true
    nonprod  = false
    dr       = true
    shared   = true
    security = true
    onprem   = false
  }

  # Segment -> destinations that must be inspected (send-via)
  inspected_flows = {
    prod    = ["shared", "onprem"]
    nonprod = ["shared", "onprem"]
    dr      = ["shared", "onprem"]
    shared  = ["onprem"]
  }

  # Segments whose internet egress goes through the inspection VPC (send-to)
  internet_segments = ["prod", "nonprod", "dr", "shared"]

  dx_allowed_prefixes = values(var.environment_cidrs)
}
