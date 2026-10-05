locals {
  managed_rule_names = keys(var.managed_rule_groups)
  rate_based_names   = keys(var.rate_based_rules)
  ip_set_names       = keys(var.ip_set_rules)
  all_rule_names     = concat(local.managed_rule_names, local.rate_based_names, local.ip_set_names)

  # AWS restricts a visibility config's metric_name to letters and digits.
  # Every name and rule key keeps its readable form for the resource's own
  # name/rule attributes; only the metric name strips the rest. The stripping
  # is done here, once, and every visibility_config reads the result.
  # Keyed by rule name; a name duplicated across two rule maps collapses to
  # one entry here, which is harmless because the duplicate_rule_names
  # precondition rejects that configuration anyway.
  metric_name_strip_pattern = "/[^A-Za-z0-9]/"
  metric_name               = replace(var.name, local.metric_name_strip_pattern, "")
  rule_metric_names = {
    for name in distinct(local.all_rule_names) : name => replace(name, local.metric_name_strip_pattern, "")
  }

  all_priorities = concat(
    [for g in values(var.managed_rule_groups) : g.priority],
    [for r in values(var.rate_based_rules) : r.priority],
    [for r in values(var.ip_set_rules) : r.priority],
  )

  # A map's own keys are already unique; a duplicate here can only come from
  # the same name used in two of the three rule maps.
  duplicate_rule_names = [
    for name in distinct(local.all_rule_names) : name
    if length([for n in local.all_rule_names : n if n == name]) > 1
  ]

  duplicate_priorities = [
    for p in distinct(local.all_priorities) : p
    if length([for x in local.all_priorities : x if x == p]) > 1
  ]

  all_metric_names = concat(
    [local.metric_name],
    [for name in local.all_rule_names : local.rule_metric_names[name]],
  )

  duplicate_metric_names = [
    for m in distinct(local.all_metric_names) : m
    if length([for x in local.all_metric_names : x if x == m]) > 1
  ]

  # Decoded once per rate-based rule that declares one; shape and content are
  # already guaranteed by the variable's own validation.
  rate_based_scope_down = {
    for key, r in var.rate_based_rules : key => (
      r.scope_down_statement_json == null ? null : jsondecode(r.scope_down_statement_json)
    )
  }

  redacted_fields = var.logging_configuration == null ? [] : var.logging_configuration.redacted_fields

  # The region segment of a Firehose or CloudWatch Logs destination ARN. An S3
  # bucket ARN carries no region (arn:<partition>:s3:::<bucket>), so this is
  # "" for S3 and the region preconditions in logging.tf skip it.
  logging_destination_region = var.logging_configuration == null ? "" : try(split(":", var.logging_configuration.log_destination_arn)[3], "")

  # Label namespaces of the AWS managed rule groups, as AWS documents them
  # (awswaf:managed:aws:<namespace>:...), mapped to the group that adds them.
  # Used only by the advisory scope_down_label_has_an_emitter check; a
  # namespace missing from this map degrades to a vendor-level match, never
  # to a false warning.
  aws_managed_label_namespaces = {
    "core-rule-set"     = "AWSManagedRulesCommonRuleSet"
    "admin-protection"  = "AWSManagedRulesAdminProtectionRuleSet"
    "known-bad-inputs"  = "AWSManagedRulesKnownBadInputsRuleSet"
    "sql-database"      = "AWSManagedRulesSQLiRuleSet"
    "linux-os"          = "AWSManagedRulesLinuxRuleSet"
    "posix-os"          = "AWSManagedRulesUnixRuleSet"
    "windows-os"        = "AWSManagedRulesWindowsRuleSet"
    "php-app"           = "AWSManagedRulesPHPRuleSet"
    "wordpress-app"     = "AWSManagedRulesWordPressRuleSet"
    "amazon-ip-list"    = "AWSManagedRulesAmazonIpReputationList"
    "anonymous-ip-list" = "AWSManagedRulesAnonymousIpList"
    "bot-control"       = "AWSManagedRulesBotControlRuleSet"
    "atp"               = "AWSManagedRulesATPRuleSet"
    "acfp"              = "AWSManagedRulesACFPRuleSet"
    "anti-ddos"         = "AWSManagedRulesAntiDDoSRuleSet"
  }

  # For every rate-based rule with a label-match scope-down statement: is
  # there a rule WAF evaluates earlier (strictly lower priority) in this ACL
  # that can plausibly add the label? Of the rules this module renders, only a
  # managed rule group adds labels (rate-based and IP set rules here declare
  # none), so:
  #   - awswaf:managed:aws:<namespace>:... with a namespace in the map above
  #     needs that specific AWS group earlier;
  #   - any other awswaf:managed:aws:... needs some earlier AWS-vendor group;
  #   - any other awswaf:managed:... (another vendor, or the shared token and
  #     captcha namespaces) needs some earlier managed group;
  #   - anything else (a custom label, a geo label) has no emitter this module
  #     can render.
  # Approximate by design: it cannot know which labels a group emits for a
  # given request or rule version, only whether an emitter is present and
  # ordered before the rate-based rule.
  rate_based_label_emitter_found = {
    for key, sd in local.rate_based_scope_down : key => (
      startswith(sd.key, "awswaf:managed:aws:") ? (
        contains(keys(local.aws_managed_label_namespaces), try(split(":", sd.key)[3], "")) ? anytrue([
          for g in values(var.managed_rule_groups) :
          g.priority < var.rate_based_rules[key].priority && lower(g.vendor_name) == "aws" && g.name == local.aws_managed_label_namespaces[split(":", sd.key)[3]]
          ]) : anytrue([
          for g in values(var.managed_rule_groups) :
          g.priority < var.rate_based_rules[key].priority && lower(g.vendor_name) == "aws"
        ])
        ) : startswith(sd.key, "awswaf:managed:") ? anytrue([
          for g in values(var.managed_rule_groups) : g.priority < var.rate_based_rules[key].priority
      ]) : false
    ) if sd != null
  }

  rate_based_rules_without_label_emitter = sort([
    for key, found in local.rate_based_label_emitter_found : key if !found
  ])
}
