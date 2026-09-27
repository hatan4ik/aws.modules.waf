locals {
  # AWS restricts a visibility config's metric_name to letters and digits.
  # Every name and rule key keeps its readable form for the resource's own
  # name/rule attributes; only the metric name strips the rest.
  metric_name = replace(var.name, "/[^A-Za-z0-9]/", "")

  managed_rule_names = keys(var.managed_rule_groups)
  rate_based_names   = keys(var.rate_based_rules)
  ip_set_names       = keys(var.ip_set_rules)
  all_rule_names     = concat(local.managed_rule_names, local.rate_based_names, local.ip_set_names)

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
    [for name in local.all_rule_names : replace(name, "/[^A-Za-z0-9]/", "")],
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
}
