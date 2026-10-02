# Pins the exact CloudWatch metric name rendered for the ACL and for every
# rule type, with keys mixing hyphens and underscores, so that how the
# stripping is computed (once, in local.rule_metric_names) can change without
# the rendered values changing.

mock_provider "aws" {}

variables {
  name  = "example-acl_v2"
  scope = "REGIONAL"

  managed_rule_groups = {
    "core-rules_1" = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
  }
  rate_based_rules = {
    "api-burst_2" = { limit = 1000, priority = 2 }
  }
  ip_set_rules = {
    "deny-list_3" = { ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/x/11111111-1111-1111-1111-111111111111", priority = 3, action = "block" }
  }
}

run "metric_names_strip_every_non_alphanumeric_character" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].metric_name == "exampleaclv2"
    error_message = "The ACL's own metric_name must be its name stripped of non-alphanumeric characters."
  }

  assert {
    condition = (
      { for r in aws_wafv2_web_acl.this.rule : r.name => r.visibility_config[0].metric_name } ==
      { "core-rules_1" = "corerules1", "api-burst_2" = "apiburst2", "deny-list_3" = "denylist3" }
    )
    error_message = "Every rule's metric_name must be its key stripped of non-alphanumeric characters, for managed, rate-based, and IP set rules alike."
  }
}
