# One web ACL per module call. Rules are declared as three separate dynamic
# "rule" blocks, one per source map (managed_rule_groups, rate_based_rules,
# ip_set_rules), rather than merged into one normalized shape: each source has
# a different statement and action/override_action pairing, and AWS does not
# care which of several "rule" blocks on this resource contributed a given
# entry to its underlying set.

resource "aws_wafv2_web_acl" "this" {
  name   = var.name
  scope  = var.scope
  region = var.region

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [true] : []
      content {}
    }
    dynamic "block" {
      for_each = var.default_action == "block" ? [true] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = var.managed_rule_groups

    content {
      name     = rule.key
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [true] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [true] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
          version     = rule.value.version

          # rule_action_overrides gives per-rule control; excluded_rules is
          # the modern replacement for the deprecated, removed excluded_rule
          # block, expressed as an override to count for each named rule. A
          # variable validation keeps the two lists disjoint.
          dynamic "rule_action_override" {
            for_each = rule.value.rule_action_overrides

            content {
              name = rule_action_override.key

              action_to_use {
                dynamic "allow" {
                  for_each = rule_action_override.value == "allow" ? [true] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value == "block" ? [true] : []
                  content {}
                }
                dynamic "count" {
                  for_each = rule_action_override.value == "count" ? [true] : []
                  content {}
                }
                dynamic "captcha" {
                  for_each = rule_action_override.value == "captcha" ? [true] : []
                  content {}
                }
                dynamic "challenge" {
                  for_each = rule_action_override.value == "challenge" ? [true] : []
                  content {}
                }
              }
            }
          }

          dynamic "rule_action_override" {
            for_each = rule.value.excluded_rules

            content {
              name = rule_action_override.value

              action_to_use {
                count {}
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        sampled_requests_enabled   = var.sampled_requests_enabled
        metric_name                = replace(rule.key, "/[^A-Za-z0-9]/", "")
      }
    }
  }

  dynamic "rule" {
    for_each = var.rate_based_rules

    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        dynamic "block" {
          for_each = rule.value.action == "block" ? [true] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "count" ? [true] : []
          content {}
        }
        dynamic "captcha" {
          for_each = rule.value.action == "captcha" ? [true] : []
          content {}
        }
        dynamic "challenge" {
          for_each = rule.value.action == "challenge" ? [true] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = rule.value.aggregate_key_type

          # AWS requires forwarded_ip_config whenever aggregate_key_type is
          # FORWARDED_IP. X-Forwarded-For and a MATCH fallback (still count a
          # request that lacks the header) are the module's fixed, documented
          # choice; a caller needing another header composes the resource
          # directly.
          dynamic "forwarded_ip_config" {
            for_each = rule.value.aggregate_key_type == "FORWARDED_IP" ? [true] : []

            content {
              header_name       = "X-Forwarded-For"
              fallback_behavior = "MATCH"
            }
          }

          dynamic "scope_down_statement" {
            for_each = rule.value.scope_down_statement_json == null ? [] : [local.rate_based_scope_down[rule.key]]

            content {
              label_match_statement {
                scope = scope_down_statement.value.scope
                key   = scope_down_statement.value.key
              }
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        sampled_requests_enabled   = var.sampled_requests_enabled
        metric_name                = replace(rule.key, "/[^A-Za-z0-9]/", "")
      }
    }
  }

  dynamic "rule" {
    for_each = var.ip_set_rules

    content {
      name     = rule.key
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "allow" ? [true] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "block" ? [true] : []
          content {}
        }
      }

      statement {
        ip_set_reference_statement {
          arn = rule.value.ip_set_arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        sampled_requests_enabled   = var.sampled_requests_enabled
        metric_name                = replace(rule.key, "/[^A-Za-z0-9]/", "")
      }
    }
  }

  dynamic "custom_response_body" {
    for_each = var.custom_response_bodies

    content {
      key          = custom_response_body.key
      content      = custom_response_body.value.content
      content_type = custom_response_body.value.content_type
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    sampled_requests_enabled   = var.sampled_requests_enabled
    metric_name                = local.metric_name
  }

  tags = var.tags

  lifecycle {
    precondition {
      condition     = var.scope != "CLOUDFRONT" || var.region == "us-east-1"
      error_message = "region must be \"us-east-1\" when scope = \"CLOUDFRONT\" — the only region WAFv2 reads a CLOUDFRONT-scope web ACL from. Set region = \"us-east-1\" and confirm your credentials have access to that region."
    }

    precondition {
      condition     = length(local.duplicate_rule_names) == 0
      error_message = "Rule names must be unique across managed_rule_groups, rate_based_rules, and ip_set_rules combined. Duplicated: ${join(", ", local.duplicate_rule_names)}."
    }

    precondition {
      condition     = length(local.duplicate_priorities) == 0
      error_message = "Rule priorities must be unique across managed_rule_groups, rate_based_rules, and ip_set_rules combined. Duplicated: ${join(", ", [for p in local.duplicate_priorities : tostring(p)])}."
    }

    precondition {
      condition     = length(local.duplicate_metric_names) == 0
      error_message = "The web ACL name and every rule name must remain distinct once non-alphanumeric characters are stripped for the CloudWatch metric name. Colliding once stripped: ${join(", ", local.duplicate_metric_names)}."
    }
  }
}
