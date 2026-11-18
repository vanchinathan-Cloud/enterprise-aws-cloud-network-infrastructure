############################################
# Cloud WAN core network, segments and policy
############################################

resource "aws_networkmanager_global_network" "this" {
  description = "Airline global network"
}

data "aws_networkmanager_core_network_policy_document" "this" {
  core_network_configuration {
    asn_ranges       = [var.core_network_asn_range]
    vpn_ecmp_support = true

    dynamic "edge_locations" {
      for_each = var.regions
      content {
        location = edge_locations.key
        asn      = tostring(edge_locations.value.edge_asn)
      }
    }
  }

  dynamic "segments" {
    for_each = local.segment_acceptance
    content {
      name                          = segments.key
      require_attachment_acceptance = segments.value
    }
  }

  # Inspection VPCs join this group; segments send traffic "via" it.
  network_function_groups {
    name                          = "inspection"
    require_attachment_acceptance = false
  }

  # Inspection VPC attachments (tag nfg=inspection) -> network function group
  attachment_policies {
    rule_number     = 100
    condition_logic = "or"

    conditions {
      type     = "tag-value"
      operator = "equals"
      key      = "nfg"
      value    = "inspection"
    }

    action {
      add_to_network_function_group = "inspection"
    }
  }

  # Any attachment tagged segment=<name> joins that segment
  attachment_policies {
    rule_number     = 200
    condition_logic = "or"

    conditions {
      type = "tag-exists"
      key  = "segment"
    }

    action {
      association_method = "tag"
      tag_value_of_key   = "segment"
    }
  }

  # East-west and on-premises flows are inspected
  dynamic "segment_actions" {
    for_each = local.inspected_flows
    content {
      action  = "send-via"
      segment = segment_actions.key
      mode    = "single-hop"

      when_sent_to {
        segments = segment_actions.value
      }

      via {
        network_function_groups = ["inspection"]
      }
    }
  }

  # Internet egress goes through the inspection VPC
  dynamic "segment_actions" {
    for_each = toset(local.internet_segments)
    content {
      action  = "send-to"
      segment = segment_actions.value

      via {
        network_function_groups = ["inspection"]
      }
    }
  }
}

resource "aws_networkmanager_core_network" "this" {
  global_network_id   = aws_networkmanager_global_network.this.id
  description         = "Airline core network"
  create_base_policy  = true
  base_policy_regions = local.region_names
}

resource "aws_networkmanager_core_network_policy_attachment" "this" {
  core_network_id = aws_networkmanager_core_network.this.id
  policy_document = data.aws_networkmanager_core_network_policy_document.this.json
}

############################################
# Direct Connect gateway (global). Transit VIFs are created with the
# DX connections / partners and attached to this gateway.
############################################

resource "aws_dx_gateway" "this" {
  name            = "airline-dx-gateway"
  amazon_side_asn = var.dx_gateway_asn
}
