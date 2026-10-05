provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

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
# named with the aws-waf-logs- prefix, and CloudWatch Logs to be granted use
# of the KMS key that encrypts it.
resource "aws_kms_key" "waf_logs" {
  description         = "Encrypts ${var.name}'s WAF log group."
  enable_key_rotation = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AccountRootAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "CloudWatchLogsEncryption"
        Effect    = "Allow"
        Principal = { Service = "logs.${var.region}.amazonaws.com" }
        Action    = ["kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:Describe*"]
        Resource  = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:aws-waf-logs-${var.name}"
          }
        }
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-${var.name}"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.waf_logs.arn
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
    redacted_fields     = ["authorization", "cookie"]
  }

  tags = { Environment = "dev", Owner = "platform" }
}
