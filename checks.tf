# Advisory checks: they warn on every plan and apply but never block. Each
# describes a configuration that is valid yet usually unintended.

check "no_automated_defense" {
  assert {
    condition     = length(var.managed_rule_groups) > 0 || length(var.rate_based_rules) > 0
    error_message = "No managed rule groups and no rate-based rules are declared. An IP set allow/block list alone (or an empty ACL) gives no automated defense against unknown attackers; consider adding at least one managed rule group or rate-based rule."
  }
}

check "managed_rule_group_count_mode" {
  assert {
    condition     = alltrue([for g in values(var.managed_rule_groups) : g.override_action != "count"])
    error_message = "One or more managed_rule_groups entries have override_action = \"count\": matches are logged but never blocked. Confirm this is intentional; count mode alone does not protect anything."
  }
}
