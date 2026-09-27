mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "override_action_count_and_vendor_name" {
  command = plan

  variables {
    managed_rule_groups = {
      bot = {
        name            = "AWSManagedRulesBotControlRuleSet"
        vendor_name     = "AWS"
        priority        = 5
        override_action = "count"
      }
    }
  }

  expect_failures = [check.managed_rule_group_count_mode]

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.name == "bot" &&
        r.priority == 5 &&
        r.statement[0].managed_rule_group_statement[0].name == "AWSManagedRulesBotControlRuleSet" &&
        length(r.override_action[0].count) == 1 &&
        length(r.override_action[0].none) == 0
      )
    ])
    error_message = "override_action = count must render the count variant of override_action."
  }
}

run "rule_action_overrides_and_excluded_rules_both_produce_rule_action_override" {
  command = plan

  variables {
    managed_rule_groups = {
      common = {
        name           = "AWSManagedRulesCommonRuleSet"
        priority       = 1
        excluded_rules = ["SizeRestrictions_BODY"]
        rule_action_overrides = {
          NoUserAgent_HEADER = "captcha"
        }
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.name == "common" &&
        length(r.statement[0].managed_rule_group_statement[0].rule_action_override) == 2
      )
    ])
    error_message = "excluded_rules and rule_action_overrides must together produce one rule_action_override block per entry."
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : anytrue([
        for override in r.statement[0].managed_rule_group_statement[0].rule_action_override :
        override.name == "SizeRestrictions_BODY" && length(override.action_to_use[0].count) == 1
      ])
    ])
    error_message = "A name in excluded_rules must render as a rule_action_override forcing count."
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : anytrue([
        for override in r.statement[0].managed_rule_group_statement[0].rule_action_override :
        override.name == "NoUserAgent_HEADER" && length(override.action_to_use[0].captcha) == 1
      ])
    ])
    error_message = "A rule_action_overrides entry must render its declared action_to_use."
  }
}

run "version_pins_the_managed_rule_group" {
  command = plan

  variables {
    managed_rule_groups = {
      common = {
        name     = "AWSManagedRulesCommonRuleSet"
        priority = 1
        version  = "Version_1.1"
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : r.statement[0].managed_rule_group_statement[0].version == "Version_1.1"
    ])
    error_message = "version must be passed through to the managed rule group statement."
  }
}

run "several_managed_rule_groups_at_distinct_priorities" {
  command = plan

  variables {
    managed_rule_groups = {
      common = {
        name     = "AWSManagedRulesCommonRuleSet"
        priority = 1
      }
      sqli = {
        name     = "AWSManagedRulesSQLiRuleSet"
        priority = 2
      }
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 2
    error_message = "Two managed_rule_groups entries must render two rules."
  }
}
