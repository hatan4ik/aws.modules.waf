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

# ---------------------------------------------------------------------------
# scope_down_label_has_an_emitter
# ---------------------------------------------------------------------------

run "scope_down_label_passes_with_its_aws_group_at_a_lower_priority" {
  command = plan

  variables {
    managed_rule_groups = {
      bot_control = { name = "AWSManagedRulesBotControlRuleSet", priority = 1 }
    }
    rate_based_rules = {
      bots = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent" })
      }
    }
  }
}

run "scope_down_namespace_passes_with_its_aws_group_at_a_lower_priority" {
  command = plan

  variables {
    managed_rule_groups = {
      ip_rep = { name = "AWSManagedRulesAmazonIpReputationList", priority = 1 }
    }
    rate_based_rules = {
      reputation = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "NAMESPACE", key = "awswaf:managed:aws:amazon-ip-list:" })
      }
    }
  }
}

run "scope_down_label_passes_for_an_unmapped_aws_namespace_with_any_earlier_aws_group" {
  command = plan

  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
    rate_based_rules = {
      future = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:aws:some-future-group:signal" })
      }
    }
  }
}

run "scope_down_label_passes_for_a_token_label_with_any_earlier_managed_group" {
  command = plan

  variables {
    managed_rule_groups = {
      bot_control = { name = "AWSManagedRulesBotControlRuleSet", priority = 1 }
    }
    rate_based_rules = {
      tokenless = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:token:absent" })
      }
    }
  }
}

run "scope_down_label_warns_when_its_group_runs_after_the_rate_based_rule" {
  command = plan

  variables {
    managed_rule_groups = {
      bot_control = { name = "AWSManagedRulesBotControlRuleSet", priority = 20 }
    }
    rate_based_rules = {
      bots = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent" })
      }
    }
  }

  expect_failures = [check.scope_down_label_has_an_emitter]
}

run "scope_down_label_warns_when_only_a_different_aws_group_runs_first" {
  command = plan

  variables {
    managed_rule_groups = {
      common = { name = "AWSManagedRulesCommonRuleSet", priority = 1 }
    }
    rate_based_rules = {
      bots = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent" })
      }
    }
  }

  expect_failures = [check.scope_down_label_has_an_emitter]
}

run "scope_down_label_warns_on_a_custom_label_no_rule_here_can_add" {
  command = plan

  variables {
    rate_based_rules = {
      tagged = {
        limit                     = 100
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "myapp:suspicious" })
      }
    }
  }

  expect_failures = [check.scope_down_label_has_an_emitter]
}
