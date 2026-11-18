variable "name" {
  description = "Short hub name (mumbai, dubai, eu)"
  type        = string
}

variable "azs" {
  description = "Exactly two availability zones"
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "The hub layout is sized for exactly two AZs."
  }
}

variable "tgw_asn" {
  type = number
}

variable "hub_ipam_pool_id" {
  description = "Regional Shared IPAM pool the hub VPCs allocate from"
  type        = string
}

variable "shared_resource_arns" {
  description = "Extra resources (IPAM pools) to share through RAM, keyed by static name"
  type        = map(string)
  default     = {}
}

variable "core_network_id" {
  type = string
}

variable "core_network_arn" {
  type = string
}

variable "dx_gateway_id" {
  type = string
}

variable "dx_allowed_prefixes" {
  type = list(string)
}

variable "environment_cidrs" {
  description = "Must contain keys production, nonprod (used for segment deny rules)"
  type        = map(string)
}

variable "onprem_cidrs" {
  type = list(string)
}

variable "vpn_cidrs" {
  type = list(string)
}

variable "onprem_domain" {
  type = string
}

variable "onprem_dns_ips" {
  type = list(string)
}

variable "egress_allowed_domains" {
  type = list(string)
}

variable "ram_principals" {
  type    = list(string)
  default = []
}

variable "enable_gwlb" {
  type    = bool
  default = false
}
