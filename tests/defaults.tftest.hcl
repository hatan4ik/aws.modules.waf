mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "defaults_render_one_managed_rule_group_and_nothing_else" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl.this.name == "example-acl" && aws_wafv2_web_acl.this.scope == "REGIONAL"
    error_message = "The web ACL must take its name and scope directly from the inputs."
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.default_action[0].allow) == 1 && length(aws_wafv2_web_acl.this.default_action[0].block) == 0
    error_message = "default_action must default to allow, the standard WAF posture."
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 1
    error_message = "A bare call must render exactly one rule: the default managed rule group."
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.name == "common" &&
        r.priority == 1 &&
        length(r.statement) == 1 &&
        r.statement[0].managed_rule_group_statement[0].name == "AWSManagedRulesCommonRuleSet" &&
        r.statement[0].managed_rule_group_statement[0].vendor_name == "AWS" &&
        r.statement[0].managed_rule_group_statement[0].version == null &&
        length(r.override_action[0].none) == 1 &&
        length(r.override_action[0].count) == 0 &&
        length(r.statement[0].managed_rule_group_statement[0].rule_action_override) == 0 &&
        r.visibility_config[0].metric_name == "common" &&
        r.visibility_config[0].cloudwatch_metrics_enabled == true &&
        r.visibility_config[0].sampled_requests_enabled == true
      )
    ])
    error_message = "The default managed_rule_groups entry must render AWSManagedRulesCommonRuleSet at priority 1 with override_action none and no rule_action_override entries."
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.custom_response_body) == 0
    error_message = "No custom_response_body must render without custom_response_bodies declared."
  }

  assert {
    condition     = aws_wafv2_web_acl.this.visibility_config[0].metric_name == "exampleacl"
    error_message = "The ACL's own metric_name must be the name stripped of non-alphanumeric characters."
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 0
    error_message = "No logging configuration must render without logging_configuration declared."
  }

  assert {
    condition     = output.web_acl_name == "example-acl"
    error_message = "web_acl_name must equal the configured name."
  }
}

run "empty_rule_maps_render_no_rules" {
  command = plan

  variables {
    managed_rule_groups = {}
  }

  expect_failures = [check.no_automated_defense]

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 0
    error_message = "Clearing every rule map must render a web ACL with no rules."
  }
}

run "block_default_action_renders_block" {
  command = plan

  variables {
    default_action = "block"
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.default_action[0].block) == 1 && length(aws_wafv2_web_acl.this.default_action[0].allow) == 0
    error_message = "default_action = block must render the block variant, not allow."
  }
}

run "tags_pass_through" {
  command = plan

  variables {
    tags = { Environment = "dev", Owner = "platform" }
  }

  assert {
    condition     = aws_wafv2_web_acl.this.tags["Environment"] == "dev" && aws_wafv2_web_acl.this.tags["Owner"] == "platform"
    error_message = "tags must be applied to the web ACL unchanged."
  }
}
