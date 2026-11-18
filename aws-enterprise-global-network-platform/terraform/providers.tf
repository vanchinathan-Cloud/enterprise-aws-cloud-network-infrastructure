############################################
# Providers: one per hub region, deployed into the Network Account
############################################

provider "aws" {
  region = var.home_region

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.tags
  }
}

provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.tags
  }
}

# me-central-1 is an opt-in region: enable it in the account first.
provider "aws" {
  alias  = "dubai"
  region = "me-central-1"

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.tags
  }
}

# AWS has no Amsterdam region; the EU hub runs in Frankfurt.
provider "aws" {
  alias  = "frankfurt"
  region = "eu-central-1"

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = var.tags
  }
}
