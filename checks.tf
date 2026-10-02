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

# A rate-based rule whose scope-down statement matches a label nothing earlier
# in the ACL adds is accepted by AWS and then never counts a single request:
# the rule silently never fires. See local.rate_based_label_emitter_found
# for exactly what "earlier" and "adds" mean here, and README.md ("Detecting a
# scope-down rule that never counts") for how an operator spots it live.
check "scope_down_label_has_an_emitter" {
  assert {
    condition     = length(local.rate_based_rules_without_label_emitter) == 0
    error_message = "Rate-based rule(s) ${join(", ", local.rate_based_rules_without_label_emitter)} scope down to a label that no rule with a strictly lower priority in this ACL appears able to add. If no earlier rule adds that label, the rule matches nothing and its metric never reports a value. Give the emitting managed rule group a lower priority than the rate-based rule, or correct the label key. This is advisory: it checks that a plausible emitter is ordered first, not that the label is actually added at runtime."
  }
}
