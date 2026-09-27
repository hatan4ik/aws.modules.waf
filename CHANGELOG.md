# Changelog

All notable changes to this module are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Consumers pin the commit SHA of a release tag; see [Versioning and releases](README.md#versioning-and-releases).

## [Unreleased]

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
