mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "rate_based_rule_with_ip_aggregation" {
  command = plan

  variables {
    managed_rule_groups = {}
    rate_based_rules = {
      api_burst = {
        limit    = 2000
        priority = 10
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.name == "api_burst" &&
        r.priority == 10 &&
        length(r.statement[0].rate_based_statement) == 1 &&
        r.statement[0].rate_based_statement[0].limit == 2000 &&
        r.statement[0].rate_based_statement[0].aggregate_key_type == "IP" &&
        length(r.statement[0].rate_based_statement[0].forwarded_ip_config) == 0 &&
        length(r.action[0].block) == 1 &&
        r.visibility_config[0].metric_name == "apiburst"
      )
    ])
    error_message = "A rate_based_rules entry must default to IP aggregation and a block action."
  }
}

run "forwarded_ip_aggregation_renders_forwarded_ip_config" {
  command = plan

  variables {
    managed_rule_groups = {}
    rate_based_rules = {
      api_burst = {
        limit              = 1000
        priority           = 10
        aggregate_key_type = "FORWARDED_IP"
        action             = "captcha"
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.statement[0].rate_based_statement[0].aggregate_key_type == "FORWARDED_IP" &&
        r.statement[0].rate_based_statement[0].forwarded_ip_config[0].header_name == "X-Forwarded-For" &&
        r.statement[0].rate_based_statement[0].forwarded_ip_config[0].fallback_behavior == "MATCH" &&
        length(r.action[0].captcha) == 1
      )
    ])
    error_message = "FORWARDED_IP aggregation must render forwarded_ip_config with X-Forwarded-For and a MATCH fallback."
  }
}

run "scope_down_statement_json_renders_label_match" {
  command = plan

  variables {
    managed_rule_groups = {}
    rate_based_rules = {
      api_burst = {
        limit                     = 1000
        priority                  = 10
        scope_down_statement_json = jsonencode({ scope = "LABEL", key = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent" })
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        length(r.statement[0].rate_based_statement[0].scope_down_statement) == 1 &&
        r.statement[0].rate_based_statement[0].scope_down_statement[0].label_match_statement[0].scope == "LABEL" &&
        r.statement[0].rate_based_statement[0].scope_down_statement[0].label_match_statement[0].key == "awswaf:managed:aws:bot-control:signal:non_browser_user_agent"
      )
    ])
    error_message = "scope_down_statement_json must render a label_match_statement with the decoded scope and key."
  }
}

run "no_scope_down_statement_by_default" {
  command = plan

  variables {
    managed_rule_groups = {}
    rate_based_rules = {
      api_burst = {
        limit    = 1000
        priority = 10
      }
    }
  }

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : length(r.statement[0].rate_based_statement[0].scope_down_statement) == 0
    ])
    error_message = "No scope_down_statement must render without scope_down_statement_json."
  }
}

run "several_rate_based_rules_and_managed_groups_coexist" {
  command = plan

  variables {
    rate_based_rules = {
      api_burst = {
        limit    = 1000
        priority = 10
      }
      login_burst = {
        limit    = 100
        priority = 11
        action   = "challenge"
      }
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 3
    error_message = "The default managed rule group plus two rate-based rules must render three rules."
  }
}
