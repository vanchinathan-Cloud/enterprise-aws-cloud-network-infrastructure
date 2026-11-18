############################################
# AWS Network Firewall (strict rule order)
############################################

locals {
  prod    = var.environment_cidrs["production"]
  nonprod = var.environment_cidrs["nonprod"]
  dr      = var.environment_cidrs["dr"]

  suricata_rules = <<-EOT
    drop ip ${local.prod} any -> ${local.nonprod} any (msg:"prod to nonprod blocked"; sid:1000001; rev:1;)
    drop ip ${local.nonprod} any -> ${local.prod} any (msg:"nonprod to prod blocked"; sid:1000002; rev:1;)
    drop ip ${local.nonprod} any -> ${local.dr} any (msg:"nonprod to dr blocked"; sid:1000003; rev:1;)
    drop ip ${local.dr} any -> ${local.nonprod} any (msg:"dr to nonprod blocked"; sid:1000004; rev:1;)
    pass ip $HOME_NET any -> $HOME_NET any (msg:"internal traffic"; sid:1000100; rev:1;)
  EOT
}

resource "aws_networkfirewall_rule_group" "segments" {
  name     = "segments-${var.name}"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = local.internal_all
        }
      }
    }

    rules_source {
      rules_string = local.suricata_rules
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

resource "aws_networkfirewall_rule_group" "egress_domains" {
  name     = "egress-domains-${var.name}"
  type     = "STATEFUL"
  capacity = 100

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = local.internal_all
        }
      }
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "ALLOWLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.egress_allowed_domains
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "inspection-${var.name}"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    # Anything not explicitly passed is dropped (and alerted) once established
    stateful_default_actions = ["aws:drop_established", "aws:alert_established"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 10
      resource_arn = aws_networkfirewall_rule_group.segments.arn
    }

    stateful_rule_group_reference {
      priority     = 20
      resource_arn = aws_networkfirewall_rule_group.egress_domains.arn
    }
  }
}

resource "aws_networkfirewall_firewall" "this" {
  name                = "inspection-${var.name}"
  vpc_id              = aws_vpc.inspection.id
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }
}

locals {
  # AZ name -> firewall endpoint ID
  fw_endpoints = {
    for s in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    s.availability_zone => s.attachment[0].endpoint_id
  }
}

resource "aws_cloudwatch_log_group" "fw_alert" {
  name              = "/network-firewall/${var.name}/alert"
  retention_in_days = 90
}

resource "aws_cloudwatch_log_group" "fw_flow" {
  name              = "/network-firewall/${var.name}/flow"
  retention_in_days = 30
}

resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination      = { logGroup = aws_cloudwatch_log_group.fw_alert.name }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination      = { logGroup = aws_cloudwatch_log_group.fw_flow.name }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
