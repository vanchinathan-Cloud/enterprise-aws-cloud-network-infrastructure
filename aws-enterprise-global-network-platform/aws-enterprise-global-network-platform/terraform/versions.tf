terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80, < 7.0"
    }
  }

  # Partial backend config; supply bucket/key/region via backend.hcl (see backend.hcl.example)
  backend "s3" {}
}
