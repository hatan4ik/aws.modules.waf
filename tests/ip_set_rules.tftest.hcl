mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "ip_set_rule_allow" {
  command = plan

  variables {
    managed_rule_groups = {}
    ip_set_rules = {
      denylist = {
        ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/denylist/11111111-1111-1111-1111-111111111111"
        priority   = 20
        action     = "block"
      }
    }
  }

  expect_failures = [check.no_automated_defense]

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : (
        r.name == "denylist" &&
        r.priority == 20 &&
        r.statement[0].ip_set_reference_statement[0].arn == "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/denylist/11111111-1111-1111-1111-111111111111" &&
        length(r.action[0].block) == 1 &&
        length(r.action[0].allow) == 0 &&
        r.visibility_config[0].metric_name == "denylist"
      )
    ])
    error_message = "An ip_set_rules entry must render an ip_set_reference_statement with the declared action."
  }
}

run "ip_set_rule_allow_action" {
  command = plan

  variables {
    managed_rule_groups = {}
    ip_set_rules = {
      allowlist = {
        ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/allowlist/22222222-2222-2222-2222-222222222222"
        priority   = 21
        action     = "allow"
      }
    }
  }

  expect_failures = [check.no_automated_defense]

  assert {
    condition = anytrue([
      for r in aws_wafv2_web_acl.this.rule : r.name == "allowlist" && length(r.action[0].allow) == 1 && length(r.action[0].block) == 0
    ])
    error_message = "action = allow must render the allow variant."
  }
}

run "ip_set_rules_alone_warns_no_automated_defense" {
  command = plan

  variables {
    managed_rule_groups = {}
    ip_set_rules = {
      denylist = {
        ip_set_arn = "arn:aws:wafv2:us-east-2:123456789012:regional/ipset/denylist/11111111-1111-1111-1111-111111111111"
        priority   = 20
        action     = "block"
      }
    }
  }

  expect_failures = [check.no_automated_defense]

  assert {
    condition     = length(aws_wafv2_web_acl.this.rule) == 1
    error_message = "An ACL with only an ip_set_rules entry must still render, just with the advisory warning."
  }
}
