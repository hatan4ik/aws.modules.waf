provider "aws" {
  region = var.region
}

module "waf" {
  source = "../../"

  name  = var.name
  scope = "REGIONAL"

  # Bot Control before the rate limit, so bad bots are blocked outright
  # rather than merely throttled; the Common rule set stays on at its
  # default priority.
  managed_rule_groups = {
    common = {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
    }
    bot_control = {
      name     = "AWSManagedRulesBotControlRuleSet"
      priority = 2
    }
  }

  # Requests AWS's Bot Control already labeled as a non-browser user agent
  # get a much lower rate limit than the general API traffic; everything
  # else is limited by source IP found in the load balancer's
  # X-Forwarded-For header.
  rate_based_rules = {
    api_traffic = {
      limit              = 5000
      priority           = 10
      aggregate_key_type = "FORWARDED_IP"
    }
    suspected_bots = {
      limit              = 200
      priority           = 11
      aggregate_key_type = "FORWARDED_IP"
      action             = "block"
      scope_down_statement_json = jsonencode({
        scope = "LABEL"
        key   = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent"
      })
    }
  }
}
