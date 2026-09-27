# ---------------------------------------------------------------------------
# Identity and scope
# ---------------------------------------------------------------------------

variable "name" {
  description = "Name of the WAFv2 web ACL. Also the base for the CloudWatch metric names of the ACL and every rule, which AWS restricts to letters and digits: each metric name is derived by stripping every other character, so every name and rule key must contain at least one letter or digit and stay distinct after stripping (a precondition names a collision)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", var.name))
    error_message = "name must be 1 to 128 characters, start with a letter or digit, and contain only letters, digits, hyphens, and underscores."
  }
}

variable "scope" {
  description = "Where the web ACL is enforced: REGIONAL (an Application Load Balancer, API Gateway REST API, AppSync GraphQL API, Cognito user pool, App Runner service, or Verified Access instance) or CLOUDFRONT (a CloudFront distribution — AWS reads CLOUDFRONT-scope web ACLs from us-east-1 only, whatever region the distribution itself serves; see region). No default: the choice is deliberate, never inherited."
  type        = string

  validation {
    condition     = contains(["REGIONAL", "CLOUDFRONT"], var.scope)
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }
}

variable "region" {
  description = "Region this web ACL, and its logging configuration when logging_configuration is set, are created in. Passed straight through as the resource's own region argument, so the result does not depend on which region the caller's default provider happens to be configured for. Required and must be \"us-east-1\" when scope = \"CLOUDFRONT\" — the only region WAFv2 accepts a CLOUDFRONT-scope web ACL from. Terraform cannot read a provider's configured region from inside a module and cannot force a resource into a region the caller's credentials cannot reach, so this is a caller-declared value the module both validates and applies: setting region = \"us-east-1\" here does not by itself grant access to that region, your credentials must have it too. Optional and unused by default for scope = \"REGIONAL\" (the ACL takes the provider's own region); set it there only to pin the ACL to a specific region in a multi-region root."
  type        = string
  default     = null

  validation {
    condition     = var.region == null ? true : can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "region, when set, must be an AWS region code such as us-east-1."
  }
}

variable "default_action" {
  description = "Action for a request that no rule matches. allow (default) is the standard WAF posture: the ACL passes non-matching traffic through and managed or custom rules block what is malicious. block makes the ACL default-deny: every request that should get through must match a rule with an allow action."
  type        = string
  default     = "allow"
  nullable    = false

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

# ---------------------------------------------------------------------------
# Rules
# ---------------------------------------------------------------------------

variable "managed_rule_groups" {
  description = "AWS or Marketplace managed rule groups, keyed by a short logical name that becomes the rule's name (unique across managed_rule_groups, rate_based_rules, and ip_set_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. name is the managed rule group's own AWS name (for example AWSManagedRulesCommonRuleSet); vendor_name defaults to AWS. priority orders evaluation and must be unique across every rule in the ACL — AWS evaluates lower numbers first. override_action is none (the group's own per-rule actions apply) or count (every rule in the group only counts a match, never blocks; see the managed_rule_group_count_mode check). excluded_rules names rules within the group to force into count mode individually, the modern equivalent of the deprecated per-group excluded_rule; rule_action_overrides maps a rule name to allow, block, count, captcha, or challenge for finer per-rule control. A rule name must not appear in both. version pins a specific managed rule group version; omit it to track AWS's default (usually latest) version. Defaults to AWS's Core rule set alone at priority 1, so a bare call is still meaningfully protected."
  type = map(object({
    name                  = string
    vendor_name           = optional(string, "AWS")
    priority              = number
    override_action       = optional(string, "none")
    excluded_rules        = optional(set(string), [])
    rule_action_overrides = optional(map(string), {})
    version               = optional(string)
  }))
  default = {
    common = {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = 1
    }
  }
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.managed_rule_groups) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", key))])
    error_message = "Every managed_rule_groups key must be 1 to 128 characters, start with a letter or digit, and contain only letters, digits, hyphens, and underscores."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : length(g.name) > 0])
    error_message = "Every managed_rule_groups entry needs a non-empty name (the managed rule group's own AWS name, for example AWSManagedRulesCommonRuleSet). Names are not checked against AWS's live catalog; a typo fails at apply time."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : length(g.vendor_name) > 0])
    error_message = "Every managed_rule_groups vendor_name must be non-empty."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : g.priority >= 0 && g.priority == floor(g.priority)])
    error_message = "Every managed_rule_groups priority must be a whole number of 0 or greater."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : contains(["none", "count"], g.override_action)])
    error_message = "Every managed_rule_groups override_action must be none or count."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : alltrue([for action in values(g.rule_action_overrides) : contains(["allow", "block", "count", "captcha", "challenge"], action)])])
    error_message = "Every managed_rule_groups rule_action_overrides value must be allow, block, count, captcha, or challenge."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : length(setintersection(g.excluded_rules, toset(keys(g.rule_action_overrides)))) == 0])
    error_message = "A rule name cannot appear in both excluded_rules and rule_action_overrides of the same managed_rule_groups entry; excluded_rules already forces count mode for that rule."
  }

  validation {
    condition     = alltrue([for g in values(var.managed_rule_groups) : g.version == null ? true : length(g.version) > 0])
    error_message = "Every managed_rule_groups version, when set, must be non-empty."
  }
}

variable "rate_based_rules" {
  description = "Rate-based rules, keyed by a short logical name that becomes the rule's name (unique across managed_rule_groups, rate_based_rules, and ip_set_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. limit is the request count in a trailing 5-minute window that trips the rule, between AWS's documented bounds of 100 and 2,000,000,000. aggregate_key_type buckets requests by source IP (IP, the default) or by the IP found in a trusted X-Forwarded-For header with a MATCH fallback, so a request missing the header still counts (FORWARDED_IP); AWS's CUSTOM_KEYS aggregation is out of scope. priority must be unique across every rule in the ACL. action is block (default), count, captcha, or challenge. scope_down_statement_json narrows which requests count toward the limit; this module renders exactly one shape, a label match against a label an earlier rule in the same ACL added — {\"scope\": \"LABEL\", \"key\": \"<label>\"} or {\"scope\": \"NAMESPACE\", \"key\": \"<namespace>\"}. Anything more elaborate (byte or geo match, IP set reference, boolean compositions) is out of scope for this string escape hatch; compose aws_wafv2_web_acl directly for that. Defaults to none, so no rate limiting applies unless declared."
  type = map(object({
    limit                     = number
    aggregate_key_type        = optional(string, "IP")
    priority                  = number
    action                    = optional(string, "block")
    scope_down_statement_json = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.rate_based_rules) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", key))])
    error_message = "Every rate_based_rules key must be 1 to 128 characters, start with a letter or digit, and contain only letters, digits, hyphens, and underscores."
  }

  validation {
    condition     = alltrue([for r in values(var.rate_based_rules) : r.limit >= 100 && r.limit <= 2000000000])
    error_message = "Every rate_based_rules limit must be between 100 and 2000000000 requests per 5-minute window, AWS's documented bounds for a rate-based rule."
  }

  validation {
    condition     = alltrue([for r in values(var.rate_based_rules) : contains(["IP", "FORWARDED_IP"], r.aggregate_key_type)])
    error_message = "Every rate_based_rules aggregate_key_type must be IP or FORWARDED_IP."
  }

  validation {
    condition     = alltrue([for r in values(var.rate_based_rules) : r.priority >= 0 && r.priority == floor(r.priority)])
    error_message = "Every rate_based_rules priority must be a whole number of 0 or greater."
  }

  validation {
    condition     = alltrue([for r in values(var.rate_based_rules) : contains(["block", "count", "captcha", "challenge"], r.action)])
    error_message = "Every rate_based_rules action must be block, count, captcha, or challenge."
  }

  validation {
    condition = alltrue([
      for r in values(var.rate_based_rules) : r.scope_down_statement_json == null ? true : (
        can(jsondecode(r.scope_down_statement_json)) ? (
          length(setsubtract(toset(keys(jsondecode(r.scope_down_statement_json))), toset(["scope", "key"]))) == 0 &&
          contains(["LABEL", "NAMESPACE"], try(jsondecode(r.scope_down_statement_json).scope, "")) &&
          try(length(jsondecode(r.scope_down_statement_json).key), 0) > 0
        ) : false
      )
    ])
    error_message = "Every rate_based_rules scope_down_statement_json, when set, must be valid JSON decoding to exactly {\"scope\": \"LABEL\"|\"NAMESPACE\", \"key\": \"<non-empty string>\"} — the only scope-down statement this module renders. Compose aws_wafv2_web_acl directly for anything more elaborate."
  }
}

variable "ip_set_rules" {
  description = "Allow or block rules referencing IP sets created and managed elsewhere (an IP set is its own lifecycle; this module does not create one), keyed by a short logical name that becomes the rule's name (unique across managed_rule_groups, rate_based_rules, and ip_set_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. ip_set_arn is the ARN of an aws_wafv2_ip_set matching this ACL's own scope and region — a REGIONAL set for a REGIONAL web ACL, a CLOUDFRONT (us-east-1) set for a CLOUDFRONT web ACL; a scope mismatch is rejected by AWS at apply time, since it is not visible from the ARN alone. priority must be unique across every rule in the ACL. action is allow or block. Defaults to none."
  type = map(object({
    ip_set_arn = string
    priority   = number
    action     = string
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.ip_set_rules) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", key))])
    error_message = "Every ip_set_rules key must be 1 to 128 characters, start with a letter or digit, and contain only letters, digits, hyphens, and underscores."
  }

  validation {
    condition     = alltrue([for r in values(var.ip_set_rules) : can(regex("^arn:[a-z0-9-]+:wafv2:[a-z0-9-]+:[0-9]{12}:(regional|global)/ipset/[a-zA-Z0-9_-]{1,128}/[0-9a-f-]{36}$", r.ip_set_arn))])
    error_message = "Every ip_set_rules ip_set_arn must be a WAFv2 IP set ARN (arn:<partition>:wafv2:<region>:<account>:(regional|global)/ipset/<name>/<id>)."
  }

  validation {
    condition     = alltrue([for r in values(var.ip_set_rules) : r.priority >= 0 && r.priority == floor(r.priority)])
    error_message = "Every ip_set_rules priority must be a whole number of 0 or greater."
  }

  validation {
    condition     = alltrue([for r in values(var.ip_set_rules) : contains(["allow", "block"], r.action)])
    error_message = "Every ip_set_rules action must be allow or block."
  }
}

# ---------------------------------------------------------------------------
# Custom responses and logging
# ---------------------------------------------------------------------------

variable "custom_response_bodies" {
  description = "Custom response bodies made available to this web ACL for a block or challenge custom response, keyed by the key a rule or the default action references. content_type is TEXT_PLAIN, TEXT_HTML, or APPLICATION_JSON; content is the body, 1 to 10240 bytes. Defaults to none."
  type = map(object({
    content      = string
    content_type = string
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for key in keys(var.custom_response_bodies) : can(regex("^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$", key))])
    error_message = "Every custom_response_bodies key must be 1 to 128 characters, start with a letter or digit, and contain only letters, digits, hyphens, and underscores."
  }

  validation {
    condition     = alltrue([for b in values(var.custom_response_bodies) : contains(["TEXT_PLAIN", "TEXT_HTML", "APPLICATION_JSON"], b.content_type)])
    error_message = "Every custom_response_bodies content_type must be TEXT_PLAIN, TEXT_HTML, or APPLICATION_JSON."
  }

  validation {
    condition     = alltrue([for b in values(var.custom_response_bodies) : length(b.content) > 0 && length(b.content) <= 10240])
    error_message = "Every custom_response_bodies content must be 1 to 10240 bytes."
  }
}

variable "logging_configuration" {
  description = "Enables web ACL logging when set. log_destination_arn is a Kinesis Data Firehose delivery stream, CloudWatch Logs log group, or S3 bucket ARN that the caller creates and owns; the module grants no permissions and creates no destination. redacted_fields lists request fields AWS omits from the logged payload, defaulting to the Authorization header even if the caller does not think to ask; the only field this module can redact is a named header (single_header) — redact the method, query string, URI path, or body by composing aws_wafv2_web_acl_logging_configuration directly. Defaults to no logging."
  type = object({
    log_destination_arn = string
    redacted_fields = optional(list(object({
      single_header = optional(string)
    })), [{ single_header = "authorization" }])
  })
  default = null

  validation {
    condition     = var.logging_configuration == null ? true : can(regex("^arn:[a-z0-9-]+:(firehose:[a-z0-9-]+:[0-9]{12}:deliverystream/.+|logs:[a-z0-9-]+:[0-9]{12}:log-group:.+|s3:::.+)$", var.logging_configuration.log_destination_arn))
    error_message = "logging_configuration.log_destination_arn must be a Kinesis Data Firehose delivery stream ARN (arn:<partition>:firehose:<region>:<account>:deliverystream/<name>), a CloudWatch Logs log group ARN (arn:<partition>:logs:<region>:<account>:log-group:<name>), or an S3 bucket ARN (arn:<partition>:s3:::<bucket>)."
  }

  validation {
    condition     = var.logging_configuration == null ? true : alltrue([for f in var.logging_configuration.redacted_fields : f.single_header != null && length(f.single_header) > 0])
    error_message = "Every logging_configuration.redacted_fields entry must set single_header to a non-empty header name; single_header is the only field type this module redacts."
  }
}

# ---------------------------------------------------------------------------
# Visibility
# ---------------------------------------------------------------------------

variable "sampled_requests_enabled" {
  description = "Whether AWS samples matched requests, applied to the web ACL's own visibility config and to every rule's. No per-rule override is exposed."
  type        = bool
  default     = true
  nullable    = false
}

variable "cloudwatch_metrics_enabled" {
  description = "Whether AWS publishes CloudWatch metrics, applied to the web ACL's own visibility config and to every rule's. No per-rule override is exposed."
  type        = bool
  default     = true
  nullable    = false
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Tags applied to the web ACL."
  type        = map(string)
  default     = {}
  nullable    = false
}
