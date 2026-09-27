provider "aws" {
  region = var.region
}

# ip_set_rules references an IP set; this module does not create one (an IP
# set is its own lifecycle). A caller normally already has one; this example
# creates a small one so the plan is self-contained.
resource "aws_wafv2_ip_set" "known_partners" {
  name               = "${var.name}-known-partners"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = ["203.0.113.0/24"]
}

# logging_configuration references a destination this module does not
# create. AWS requires a CloudWatch Logs destination for WAF logging to be
# named with the aws-waf-logs- prefix.
resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = 30
}

module "waf" {
  source = "../../"

  name  = var.name
  scope = "REGIONAL"

  managed_rule_groups = {
    common = {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
    }
    # override_action = "count" here is deliberate, to demonstrate the
    # managed_rule_group_count_mode advisory check; it does not fail the
    # plan or apply, only warns.
    bot_control = {
      name            = "AWSManagedRulesBotControlRuleSet"
      priority        = 2
      override_action = "count"
      excluded_rules  = ["CategoryAdvertising"]
    }
  }

  rate_based_rules = {
    api_traffic = {
      limit    = 2000
      priority = 10
      action   = "block"
    }
  }

  ip_set_rules = {
    known_partners = {
      ip_set_arn = aws_wafv2_ip_set.known_partners.arn
      priority   = 20
      action     = "allow"
    }
  }

  custom_response_bodies = {
    blocked = {
      content      = jsonencode({ error = "request blocked by web application firewall" })
      content_type = "APPLICATION_JSON"
    }
  }

  logging_configuration = {
    log_destination_arn = aws_cloudwatch_log_group.waf.arn
    redacted_fields = [
      { single_header = "authorization" },
      { single_header = "cookie" },
    ]
  }

  tags = { Environment = "dev", Owner = "platform" }
}
