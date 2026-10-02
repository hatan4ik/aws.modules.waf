# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

This release contains a breaking input change (`redacted_fields`), so it is versioned **2.0.0**. No known consumer instantiates this module yet (checked across the `hatan4ik` organisation; `aws.modules.alb`'s `with-waf` example takes a plain ACL ARN), so migration cost is nil in practice, but the published v1 contract changed, and Semantic Versioning, which this file commits to, makes that a major bump.

### Changed (breaking)

- `logging_configuration.redacted_fields` is now `list(string)`, a list of header names, instead of `list(object({ single_header = optional(string) }))`. The old type allowed an entry with no `single_header`, which a validation then had to reject. Default is now `["authorization"]`. Migration: `[{ single_header = "authorization" }, { single_header = "cookie" }]` becomes `["authorization", "cookie"]`. The rendered `redacted_fields { single_header { name = ... } }` blocks are unchanged, so migrating produces no diff.
- `logging_configuration.log_destination_arn` must name a destination (Firehose delivery stream, CloudWatch Logs log group, or S3 bucket; for S3 the bucket, not a key prefix) whose name starts with `aws-waf-logs-`. AWS already rejected any other name at apply time; this moves the failure to plan time. No configuration that applied before is rejected now.
- New preconditions on `aws_wafv2_web_acl_logging_configuration.this`: a Firehose or CloudWatch Logs destination must be in `us-east-1` when `scope = "CLOUDFRONT"`, and in `region` whenever `region` is set. AWS requires both and otherwise fails at apply. S3 bucket ARNs carry no region and are not checked.

### Added

- Advisory check `scope_down_label_has_an_emitter`: warns when a rate-based rule's `scope_down_statement_json` matches a label that no managed rule group with a strictly lower priority can plausibly add. Such a rule is accepted by AWS and then never counts anything. README section "Detecting a scope-down rule that never counts" describes the live symptoms: no CloudWatch datapoints, since WAF publishes rule metrics only for non-zero values.
- `region` accepts GovCloud and ISO region codes (`us-gov-west-1`, `us-iso-east-1`, `us-isob-east-1`), using the same pattern as `aws.modules.global-accelerator`.

### Fixed

- `rate_based_rules[*].limit` minimum lowered from 100 to 10, matching the WAFv2 API's current `RateBasedStatement.Limit` range (10 to 2,000,000,000). Non-integer limits are now rejected at plan time.
- `examples/rate-limited-api` aggregated by `FORWARDED_IP` on a REGIONAL ACL attached directly to an internet-facing resource. With no trusted proxy in front, the client controls `X-Forwarded-For` and could rotate it to bypass the limit. The example now aggregates by `IP` and explains when `FORWARDED_IP` is safe. The `rate_based_rules` description and `docs/DESIGN.md` carry the same caveat.
- `custom_response_bodies` description no longer claims that a rule or the default action references the bodies. Nothing in this module does.

### Internal

- CloudWatch metric-name stripping is computed once (`local.rule_metric_names`, one shared pattern) instead of at five call sites. Rendered metric names are unchanged, pinned by the new `tests/metric_names.tftest.hcl`, which also passes against v1.0.0.

## [1.0.0] - 2026-09-27

Initial release. One `aws_wafv2_web_acl` per module call.

### Added

- `name`, `scope` (`REGIONAL` or `CLOUDFRONT`, no default), `region` (required and validated to be `us-east-1` when `scope = "CLOUDFRONT"`, applied through the AWS provider's own per-resource `region` argument), `default_action` (`allow` by default).
- `managed_rule_groups`, a map defaulting to `AWSManagedRulesCommonRuleSet` at priority 1, so a bare call is still meaningfully protected. `excluded_rules` and `rule_action_overrides` both render as `rule_action_override` blocks (the provider removed the older `excluded_rule` block); a validation keeps the two lists disjoint per entry.
- `rate_based_rules`, a map supporting `IP` and `FORWARDED_IP` aggregation (the latter rendering a fixed, documented `forwarded_ip_config`) and a `scope_down_statement_json` string that renders exactly one supported shape: a `label_match_statement` decoded from `{"scope": "LABEL"|"NAMESPACE", "key": "..."}`.
- `ip_set_rules`, a map referencing an existing `aws_wafv2_ip_set` ARN by allow or block action. The module does not create IP sets.
- `custom_response_bodies`, rendered as `custom_response_body` blocks on the web ACL.
- `logging_configuration`, opt-in, defaulting `redacted_fields` to `[{ single_header = "authorization" }]` even when not asked for. Accepts a Kinesis Data Firehose, CloudWatch Logs, or S3 bucket ARN as the destination.
- `sampled_requests_enabled` and `cloudwatch_metrics_enabled` (both default `true`), applied uniformly to the ACL's own visibility config and every rule's.
- `tags`.
- Outputs `web_acl_arn`, `web_acl_id`, `web_acl_name`, `web_acl_capacity`.
- Plan-time validation of every input, including: name and rule-key syntax (and its consequence for the derived CloudWatch metric name); rate limit bounds (100 to 2,000,000,000); managed rule group, rate-based rule, and IP set rule shapes; custom response body size (10,240 bytes) and content type; the logging destination ARN shape; and the `scope_down_statement_json` shape.
- Three cross-map `lifecycle.precondition`s on the web ACL: rule names unique across `managed_rule_groups`, `rate_based_rules`, and `ip_set_rules` combined; priorities unique across the same three maps; and the same three maps' names (and the ACL's own name) distinct once stripped for their CloudWatch metric names.
- Advisory `check` blocks: `no_automated_defense` (warns when no managed rule group and no rate-based rule is declared) and `managed_rule_group_count_mode` (warns when a managed rule group's `override_action` is `count`).
- Mock-provider contract tests in `tests/` covering every input, every validation and precondition (`tests/validation.tftest.hcl`), both scopes, logging with and without a redaction override, and the genuinely AWS-computed outputs (`tests/outputs_apply.tftest.hcl`, `command = apply` with a mocked resource).
- Examples `minimal`, `cloudfront-scope`, `rate-limited-api`, and `full-featured`.
- Credential-driven integration suite `smoke` in `tests/integration/`, a `make integration-smoke` target, a dispatch-only `integration` workflow that assumes a role through GitHub OIDC from the protected `integration` environment, and the IAM trust and permissions documents the role needs.
- `docs/DESIGN.md`, `CONTRIBUTING.md`, `SECURITY.md`, `LICENSE`, the `Makefile` quality gate, pre-commit, tflint, and terraform-docs configuration, Dependabot, issue and pull request templates, and the `module-release` workflow.

[Unreleased]: https://github.com/hatan4ik/aws.modules.waf/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/hatan4ik/aws.modules.waf/releases/tag/v1.0.0
