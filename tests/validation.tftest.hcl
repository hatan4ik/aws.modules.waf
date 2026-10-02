# Every variable validation and resource precondition, each with a failing
# case pinned by expect_failures. command = plan throughout: nothing here
# talks to AWS.

mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "baseline_is_valid" {
  command = plan
}

# ---------------------------------------------------------------------------
# name / scope / region / default_action
# ---------------------------------------------------------------------------

run "name_must_match_the_pattern" {
  command = plan
  variables {
    name = "-leading-hyphen"
  }
  expect_failures = [var.name]
}

run "name_must_not_be_empty" {
  command = plan
  variables {
    name = ""
  }
  expect_failures = [var.name]
}

run "scope_must_be_regional_or_cloudfront" {
  command = plan
  variables {
    scope = "GLOBAL"
  }
  expect_failures = [var.scope]
}

run "region_must_look_like_a_region_code" {
  command = plan
  variables {
    region = "not-a-region"
  }
  expect_failures = [var.region]
}

run "region_must_not_have_a_partition_typo" {
  command = plan
  variables {
    region = "us-gv-west-1-a"
  }
  expect_failures = [var.region]
}

run "region_accepts_govcloud_and_iso_region_codes" {
  command = plan
  variables {
    region = "us-gov-west-1"
  }
}

run "region_accepts_iso_region_codes" {
  command = plan
  variables {
    region = "us-isob-east-1"
  }
}

run "default_action_must_be_allow_or_block" {
  command = plan
  variables {
    default_action = "monitor"
  }
  expect_failures = [var.default_action]
}

# ---------------------------------------------------------------------------
# managed_rule_groups
# ---------------------------------------------------------------------------

run "managed_rule_groups_key_must_match_the_pattern" {
  command = plan
  variables {
    managed_rule_groups = {
      "-bad" = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_name_must_be_non_empty" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "", priority = 1 }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_vendor_name_must_be_non_empty" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", vendor_name = "", priority = 1 }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_priority_must_be_a_non_negative_whole_number" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = -1 }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_priority_must_be_a_whole_number" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1.5 }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_override_action_must_be_none_or_count" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1, override_action = "block" }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_rule_action_overrides_value_must_be_a_known_action" {
  command = plan
  variables {
    managed_rule_groups = {
      common = {
        name                  = "AWSManagedRulesCommonRuleSet"
        priority              = 1
        rule_action_overrides = { SizeRestrictions_BODY = "deny" }
      }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_excluded_rules_and_rule_action_overrides_must_be_disjoint" {
  command = plan
  variables {
    managed_rule_groups = {
      common = {
        name                  = "AWSManagedRulesCommonRuleSet"
        priority              = 1
        excluded_rules        = ["SizeRestrictions_BODY"]
        rule_action_overrides = { SizeRestrictions_BODY = "count" }
      }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

run "managed_rule_groups_version_must_be_non_empty_when_set" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1, version = "" }
    }
  }
  expect_failures = [var.managed_rule_groups]
}

# ---------------------------------------------------------------------------
# rate_based_rules
# ---------------------------------------------------------------------------

run "rate_based_rules_key_must_match_the_pattern" {
  command = plan
  variables {
    rate_based_rules = {
      "bad key" = { limit = 1000, priority = 10 }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_limit_must_be_at_least_10" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 9, priority = 10 }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_limit_accepts_the_aws_minimum_of_10" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 10, priority = 10 }
    }
  }
}

run "rate_based_rules_limit_must_be_a_whole_number" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 100.5, priority = 10 }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_limit_must_be_at_most_two_billion" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 2000000001, priority = 10 }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_aggregate_key_type_must_be_ip_or_forwarded_ip" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = 10, aggregate_key_type = "CUSTOM_KEYS" }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_priority_must_be_a_non_negative_whole_number" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = -1 }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_action_must_be_known" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = 10, action = "deny" }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_scope_down_statement_json_must_be_valid_json" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = 10, scope_down_statement_json = "{not json" }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_scope_down_statement_json_must_match_the_supported_shape" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = 10, scope_down_statement_json = jsonencode({ byte_match_statement = {} }) }
    }
  }
  expect_failures = [var.rate_based_rules]
}

run "rate_based_rules_scope_down_statement_json_scope_must_be_label_or_namespace" {
  command = plan
  variables {
    rate_based_rules = {
      api = { limit = 1000, priority = 10, scope_down_statement_json = jsonencode({ scope = "COUNTRY", key = "US" }) }
    }
  }
  expect_failures = [var.rate_based_rules]
}

# ---------------------------------------------------------------------------
# ip_set_rules
# ---------------------------------------------------------------------------

run "ip_set_rules_key_must_match_the_pattern" {
  command = plan
  variables {
    ip_set_rules = {
      "bad key" = { ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/x/11111111-1111-1111-1111-111111111111", priority = 20, action = "block" }
    }
  }
  expect_failures = [var.ip_set_rules]
}

run "ip_set_rules_ip_set_arn_must_be_a_wafv2_ip_set_arn" {
  command = plan
  variables {
    ip_set_rules = {
      denylist = { ip_set_arn = "arn:aws:s3:::not-an-ip-set", priority = 20, action = "block" }
    }
  }
  expect_failures = [var.ip_set_rules]
}

run "ip_set_rules_priority_must_be_a_non_negative_whole_number" {
  command = plan
  variables {
    ip_set_rules = {
      denylist = { ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/x/11111111-1111-1111-1111-111111111111", priority = -1, action = "block" }
    }
  }
  expect_failures = [var.ip_set_rules]
}

run "ip_set_rules_action_must_be_allow_or_block" {
  command = plan
  variables {
    ip_set_rules = {
      denylist = { ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/x/11111111-1111-1111-1111-111111111111", priority = 20, action = "count" }
    }
  }
  expect_failures = [var.ip_set_rules]
}

# ---------------------------------------------------------------------------
# custom_response_bodies
# ---------------------------------------------------------------------------

run "custom_response_bodies_key_must_match_the_pattern" {
  command = plan
  variables {
    custom_response_bodies = {
      "bad key" = { content = "blocked", content_type = "TEXT_PLAIN" }
    }
  }
  expect_failures = [var.custom_response_bodies]
}

run "custom_response_bodies_content_type_must_be_known" {
  command = plan
  variables {
    custom_response_bodies = {
      blocked = { content = "blocked", content_type = "TEXT_XML" }
    }
  }
  expect_failures = [var.custom_response_bodies]
}

run "custom_response_bodies_content_must_be_non_empty" {
  command = plan
  variables {
    custom_response_bodies = {
      blocked = { content = "", content_type = "TEXT_PLAIN" }
    }
  }
  expect_failures = [var.custom_response_bodies]
}

run "custom_response_bodies_content_must_not_exceed_10240_bytes" {
  command = plan
  variables {
    custom_response_bodies = {
      blocked = { content = join("", [for i in range(1024) : "0123456789a"]), content_type = "TEXT_PLAIN" }
    }
  }
  expect_failures = [var.custom_response_bodies]
}

# ---------------------------------------------------------------------------
# logging_configuration
# ---------------------------------------------------------------------------

run "logging_configuration_log_destination_arn_must_be_a_known_shape" {
  command = plan
  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:dynamodb:us-east-2:123456789012:table/not-a-log-destination"
    }
  }
  expect_failures = [var.logging_configuration]
}

run "logging_configuration_log_group_name_must_start_with_aws_waf_logs" {
  command = plan
  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:/aws/waf/example-acl"
    }
  }
  expect_failures = [var.logging_configuration]
}

run "logging_configuration_firehose_name_must_start_with_aws_waf_logs" {
  command = plan
  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:firehose:us-east-2:123456789012:deliverystream/waf-logs-example"
    }
  }
  expect_failures = [var.logging_configuration]
}

run "logging_configuration_s3_bucket_name_must_start_with_aws_waf_logs" {
  command = plan
  variables {
    logging_configuration = {
      # The prefix must be on the bucket name itself, not on a key prefix.
      log_destination_arn = "arn:aws:s3:::example-logs/aws-waf-logs-example"
    }
  }
  expect_failures = [var.logging_configuration]
}

run "logging_configuration_must_be_in_us_east_1_for_cloudfront_scope" {
  command = plan
  variables {
    scope  = "CLOUDFRONT"
    region = "us-east-1"
    logging_configuration = {
      log_destination_arn = "arn:aws:firehose:us-west-2:123456789012:deliverystream/aws-waf-logs-example"
    }
  }
  # Both region preconditions fire: the CLOUDFRONT-specific one and the
  # general same-region one (region is us-east-1 here).
  expect_failures = [aws_wafv2_web_acl_logging_configuration.this]
}

run "logging_configuration_must_be_in_the_pinned_region_for_regional_scope" {
  command = plan
  variables {
    region = "eu-west-1"
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl"
    }
  }
  expect_failures = [aws_wafv2_web_acl_logging_configuration.this]
}

run "logging_configuration_redacted_fields_entries_must_be_non_empty" {
  command = plan
  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl"
      redacted_fields     = [""]
    }
  }
  expect_failures = [var.logging_configuration]
}

# ---------------------------------------------------------------------------
# Cross-map preconditions on the web ACL itself
# ---------------------------------------------------------------------------

run "rule_names_must_be_unique_across_every_rule_map" {
  command = plan
  variables {
    managed_rule_groups = {
      shared = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
    rate_based_rules = {
      shared = { limit = 1000, priority = 10 }
    }
  }
  expect_failures = [aws_wafv2_web_acl.this]
}

run "priorities_must_be_unique_across_every_rule_map" {
  command = plan
  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
    rate_based_rules = {
      api = { limit = 1000, priority = 1 }
    }
  }
  expect_failures = [aws_wafv2_web_acl.this]
}

run "metric_names_must_be_distinct_once_stripped" {
  command = plan
  variables {
    managed_rule_groups = {
      "api-burst" = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
    rate_based_rules = {
      "api_burst" = { limit = 1000, priority = 2 }
    }
  }
  expect_failures = [aws_wafv2_web_acl.this]
}
