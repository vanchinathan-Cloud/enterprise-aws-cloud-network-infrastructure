variable "home_region" {
  description = "Control Tower home region and default provider region"
  type        = string
  default     = "ap-south-1"
}

variable "assume_role_arn" {
  description = "Role in the Network Account assumed by the pipeline (null = use ambient credentials)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default = {
    Application = "global-network-platform"
    Owner       = "network-engineering"
    CostCenter  = "CHANGE-ME"
    ManagedBy   = "terraform"
  }
}

variable "regions" {
  description = "Hub regions. slot = index of the /18 inside each environment /16."
  type = map(object({
    name     = string
    slot     = number
    azs      = list(string)
    edge_asn = number
    tgw_asn  = number
  }))
  default = {
    "ap-south-1" = {
      name     = "mumbai"
      slot     = 0
      azs      = ["ap-south-1a", "ap-south-1b"]
      edge_asn = 64512
      tgw_asn  = 64601
    }
    "me-central-1" = {
      name     = "dubai"
      slot     = 1
      azs      = ["me-central-1a", "me-central-1b"]
      edge_asn = 64513
      tgw_asn  = 64602
    }
    "eu-central-1" = {
      name     = "eu"
      slot     = 2
      azs      = ["eu-central-1a", "eu-central-1b"]
      edge_asn = 64514
      tgw_asn  = 64603
    }
  }
}

variable "environment_cidrs" {
  description = "One /16 per environment. Each is split into four /18s (3 regions + 1 spare)."
  type        = map(string)
  default = {
    production = "10.10.0.0/16"
    shared     = "10.20.0.0/16"
    nonprod    = "10.30.0.0/16"
    dr         = "10.40.0.0/16"
    security   = "10.50.0.0/16"
  }
}

variable "onprem_cidrs" {
  description = "On-premises ranges reached over Direct Connect"
  type        = list(string)
  default     = ["172.16.0.0/12"]
}

variable "vpn_cidrs" {
  description = "VPN ranges (backup path / remote access)"
  type        = list(string)
  default     = ["192.168.0.0/24"]
}

variable "dx_gateway_asn" {
  description = "Amazon-side ASN of the Direct Connect gateway (must differ from Cloud WAN and TGW ASNs)"
  type        = number
  default     = 64600
}

variable "core_network_asn_range" {
  description = "ASN range for Cloud WAN edges"
  type        = string
  default     = "64512-64520"
}

variable "onprem_domain" {
  description = "On-premises DNS domain forwarded by Route 53 Resolver"
  type        = string
  default     = "corp.airline.example"
}

variable "onprem_dns_ips" {
  description = "On-premises DNS server IPs (inside the DX range). Placeholders: replace."
  type        = list(string)
  default     = ["172.16.10.10", "172.16.10.11"]
}

variable "egress_allowed_domains" {
  description = "Domains allowed for internet egress through Network Firewall"
  type        = list(string)
  default     = [".amazonaws.com"]
}

variable "ram_principals" {
  description = "Organization or OU ARNs that receive IPAM pools and Resolver rules through RAM"
  type        = list(string)
  default     = []
}

variable "enable_gwlb" {
  description = "Deploy a Gateway Load Balancer and endpoint service in each inspection VPC"
  type        = bool
  default     = false
}
