# The advisory checks are also exercised inline in the rule-type test files
# where they are naturally triggered (ip_set_rules.tftest.hcl,
# managed_rule_groups.tftest.hcl, defaults.tftest.hcl). This file pins their
# passing side explicitly, so a regression that makes a check fire when it
# should not is caught here rather than only as an unrelated test's failure.

mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "no_automated_defense_passes_with_the_default_managed_rule_group" {
  command = plan
}

run "no_automated_defense_passes_with_only_a_rate_based_rule" {
  command = plan

  variables {
    managed_rule_groups = {}
    rate_based_rules = {
      api = { limit = 1000, priority = 1 }
    }
  }
}

run "managed_rule_group_count_mode_passes_with_override_action_none" {
  command = plan

  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1, override_action = "none" }
    }
  }
}
