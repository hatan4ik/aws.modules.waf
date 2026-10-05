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
  # get a much lower rate limit than the general API traffic. Both rules
  # aggregate by IP (the default): the address of the connection that reached
  # the protected resource. A REGIONAL web ACL attached directly to an
  # internet-facing ALB or API Gateway sees the real client address there.
  #
  # Do not switch to FORWARDED_IP in this topology. With no trusted proxy in
  # front, the client writes X-Forwarded-For itself and can put a different
  # address in it on every request, so each request lands in a fresh bucket
  # and the limit never trips. FORWARDED_IP is only safe behind a proxy you
  # control (CloudFront, say) that overwrites the header, and even then the
  # simpler option is usually to attach a CLOUDFRONT-scope web ACL at that
  # proxy and keep IP aggregation.
  rate_based_rules = {
    api_traffic = {
      limit    = 5000
      priority = 10
    }
    suspected_bots = {
      limit    = 200
      priority = 11
      action   = "block"
      scope_down_statement_json = jsonencode({
        scope = "LABEL"
        key   = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent"
      })
    }
  }
}
