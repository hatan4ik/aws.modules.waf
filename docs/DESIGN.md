# Design: aws.modules.waf v1

Status: accepted 2026-09-27. Brand new module; no prior version, no
`docs/UPGRADE-1.0.md`.

## Purpose

`aws.modules.waf` provisions **one** AWS WAFv2 web ACL per module call. It
implements the "WAF at each entry layer" and "WAF bot/fraud controls" line of
[ADR 0004](../../../../docs/adr/0004-edge-ingress-and-egress.md): the same
module is used by `aws.modules.alb` (`scope = "REGIONAL"`, protecting a
regional ALB, API Gateway REST API, AppSync API, Cognito user pool, App
Runner service, or Verified Access instance) and by `aws.modules.cloudfront`
(`scope = "CLOUDFRONT"`, protecting a CloudFront distribution). The ADR treats
managed rule groups and bot/fraud controls as a finance-approved cost a
caller turns on deliberately; this module makes that possible without
choosing it for anyone — `default_action` defaults to `allow` (the standard
WAF posture) and `managed_rule_groups` defaults to one entry
(`AWSManagedRulesCommonRuleSet`) so a bare call is still meaningfully
protected, matching the "secure by default, explicit by declaration" pattern
of every other module in this series.

The module deliberately does **not** create IP sets (`ip_set_rules`
references an `aws_wafv2_ip_set` ARN the caller creates and manages — an IP
set is its own lifecycle), logging destinations (a Firehose stream, log
group, or bucket the caller creates and owns), or the resources a web ACL
protects (an ALB, a CloudFront distribution, an API). It consumes ARNs and
exposes the web ACL's own identity and computed capacity.

## Why scope needs a region, and why this module does not use `configuration_aliases`

AWS reads a `CLOUDFRONT`-scope web ACL from `us-east-1` only, regardless of
where the protected distribution's origin lives. A module cannot introspect
which region its own default provider is configured for and cannot force a
resource into a region its caller's credentials cannot reach, so the
question is how to make the `us-east-1` requirement both enforced and
honest about whose responsibility it is.

The AWS provider line this module targets (`>= 6.35.0, < 7.0.0`; verified
against the installed `6.66.0`) added a `region` argument directly on
`aws_wafv2_web_acl` and `aws_wafv2_web_acl_logging_configuration` — a
per-resource region override that did not exist when `aws.modules.acm` and
`aws.modules.state` were designed against an older provider baseline. Those
two modules solved the same "this must land in a specific region" problem
the older way: an aliased provider the caller passes explicitly through
`providers = { aws = aws.us_east_1 }` (`aws.modules.acm`'s `examples/cloudfront`)
or a `configuration_aliases` entry the module itself declares
(`aws.modules.state`'s replica-region provider).

`configuration_aliases` was considered and rejected here. Declaring
`configuration_aliases = [aws.us_east_1]` in this module's `versions.tf`
would force **every** call to the module — including `examples/minimal`,
which the brief requires to be regional defaults only with no provider
wiring at all — to pass an explicit `providers` block naming that alias,
because Terraform resolves a module's declared provider requirements
statically, before `scope` is known to be `REGIONAL` or `CLOUDFRONT`. That
is the wrong trade for a module where CLOUDFRONT is one of two scopes, not
`aws.modules.state`'s replica bucket, which every call provisions.

Instead: `region` is a plain optional input, passed straight through as the
`region` argument on both resources. It is `null` (the provider's own
region) unless set, and a `lifecycle.precondition` on `aws_wafv2_web_acl.this`
rejects `scope = "CLOUDFRONT"` unless `region == "us-east-1"` exactly — a
deliberate, caller-declared choice, not a module-supplied default, so a
caller cannot get a `CLOUDFRONT` ACL in the wrong place by omission. This
does **not** remove the caller's own responsibility: passing
`region = "us-east-1"` here does not grant access to that region — the
caller's credentials must have it, the same "the caller must wire it
correctly" honesty `aws.modules.state` documents for its replica provider.
The difference is *how* that correctness is wired: a resource argument
this module sets and validates itself, not a second provider configuration
every caller must remember to pass whether or not they need it. This is
called out here, in the README's region section, and in the
`cloudfront-scope` example, precisely because it is a deviation from what a
literal reading of the brief describes and worth being explicit about.

## `scope_down_statement_json`: a bounded escape hatch, not a JSON compiler

`rate_based_rules[*].scope_down_statement_json` exists so a rate-based rule
can be scoped to requests an earlier rule already labeled (the AWS-recommended
way to combine a managed rule group with a rate limit: label first, rate-limit
the label). The underlying `rate_based_statement.scope_down_statement` schema,
though, is the same recursive statement tree as a full WAF rule: `and`/`or`/
`not` compositions over byte match, geo match, IP set reference, label match,
regex, regex-pattern-set, size constraint, SQLi, and XSS statements, each with
its own `field_to_match` and `text_transformation` shapes. Generically
compiling arbitrary JSON into that tree is a module of its own, not one
optional string field.

This module renders exactly one shape: a `label_match_statement` decoded from
`{"scope": "LABEL"|"NAMESPACE", "key": "<label or namespace>"}`. The variable
validation rejects anything else at plan time with a message naming the
supported shape. A caller needing a byte match, a geo restriction, or a
boolean composition for a rate-based rule's scope-down composes
`aws_wafv2_web_acl` directly; this is the same "an IP set is its own
lifecycle" scope boundary the brief draws for `ip_set_rules`, applied to a
field the brief specified only as `optional(string)` without prescribing its
supported shape.

## Other bounded scope choices

- `rate_based_rules[*].aggregate_key_type` accepts `IP` (the default) and
  `FORWARDED_IP`. AWS's third option, `CUSTOM_KEYS`, needs its own nested
  configuration (a combination of up to five of: ASN, cookie, forwarded IP,
  header, HTTP method, IP, JA3/JA4 fingerprint, a label namespace, a query
  argument, the query string, or the URI path, several needing their own
  `text_transformation` list) that a flat `rate_based_rules` map cannot
  express cleanly. Out of scope; compose the resource directly for it.
- Choosing `FORWARDED_IP` renders `forwarded_ip_config` with a fixed,
  documented choice: `header_name = "X-Forwarded-For"`,
  `fallback_behavior = "MATCH"` (a request missing the header still counts,
  the fail-closed choice). A caller trusting a different header composes the
  resource directly.
- `managed_rule_groups[*].excluded_rules` and `rule_action_overrides` both
  render as `rule_action_override` blocks — AWS removed the older, simpler
  `excluded_rule` block from the provider this module targets in favor of
  `rule_action_override` exclusively. `excluded_rules` is kept as its own
  input because "exclude this rule" (force it to `count`) is a common,
  simple ask that reads better as a set of names than as
  `rule_action_overrides = { name = "count" }` repeated; a variable
  validation keeps the two lists disjoint per managed rule group so the same
  rule name is never overridden twice.
- `custom_response_bodies` renders `custom_response_body` blocks on the web
  ACL so they exist to reference, but no rule or default-action shape this
  module exposes wires a `custom_response_body_key` back to one — the brief's
  interface has no such field on `managed_rule_groups`, `rate_based_rules`,
  or `ip_set_rules`. A caller referencing a custom response body from a rule
  this module does not model composes `aws_wafv2_web_acl` directly.

## Metric names

AWS restricts a visibility config's `metric_name` to letters and digits
only, while `name` (the ACL) and every rule map's keys commonly use hyphens
or underscores for readability. Rather than expose a second, stricter naming
convention as its own input, the module derives every metric name by
stripping non-alphanumeric characters from `name` or the rule's map key, and
a `name`/key validation requires at least one leading alphanumeric character
so the stripped result is never empty. A `lifecycle.precondition` rejects two
names that collide only after stripping (`api-burst` and `api_burst` would
otherwise both become `apiburst`), alongside the two AWS-mandated
preconditions: rule names unique across all three rule maps, and priorities
unique across all three rule maps.

## Principles and how the module applies them

- **Single responsibility.** The module owns one web ACL and its rules,
  nothing else. Concerns are split by file: `web_acl.tf` (the ACL and every
  rule, plus the cross-map preconditions), `logging.tf` (the opt-in logging
  configuration), `locals.tf` (metric names, collision detection, decoded
  scope-down statements), `checks.tf` (advisory warnings).
- **Open/closed.** A new managed rule group, rate-based rule, or IP set rule
  arrives as another map entry; no mode requires editing the module.
- **Liskov substitution.** `web_acl_arn` means the same thing for a regional
  or a CloudFront-scope ACL: the ARN a consumer attaches to its own resource.
- **Interface segregation.** Each rule source's own fields are independent:
  a managed rule group needs `name` and `priority`; a rate-based rule needs
  `limit`; an IP set rule needs `ip_set_arn`. Nothing in one rule map's shape
  leaks into another's.
- **Dependency inversion.** The module depends on identifiers (an IP set
  ARN, a logging destination ARN) and a region string, never on how they were
  produced or which provider configuration resolved them, and performs no
  data-source reads.

## Architecture

```text
root (one web ACL)
├── variables.tf   Inputs grouped by concern: identity/scope, rules, responses/logging, visibility, tags.
├── locals.tf      Metric names, rule-name/priority/metric-name collision detection, decoded scope-down statements.
├── web_acl.tf     aws_wafv2_web_acl.this: default_action, three dynamic "rule" blocks, custom_response_body, cross-map preconditions.
├── logging.tf     aws_wafv2_web_acl_logging_configuration.this[0], redaction defaults.
├── checks.tf      Advisory checks: no_automated_defense, managed_rule_group_count_mode.
└── outputs.tf     web_acl_arn, web_acl_id, web_acl_name, web_acl_capacity.
```

## Testing strategy

- Contract tests (`tests/`) use `mock_provider` with `command = plan`; no
  credentials. `capacity`, `arn`, and `id` are genuinely computed by AWS and
  unknown under plan, so the one assertion on them
  (`tests/outputs_apply.tftest.hcl`) uses `command = apply` with a
  `mock_resource` default and lives in its own file, isolated from every
  plan-only run.
- `rule` and `custom_response_body` are set-nested blocks in the AWS
  provider's schema: they cannot be indexed by position. Assertions that
  need one specific rule's fields either restrict the rule maps under test
  to a single homogeneous shape so `anytrue([for r in ... : r.field == ...])`
  never evaluates a field absent from a different rule's statement type
  (`&&` does not short-circuit in Terraform 1.7, so a mixed-shape iteration
  raises "Invalid index" instead of returning false), or filter by name
  first (`[for r in ... : r if r.name == "x"]`) before indexing into the
  result.
- Every variable validation and resource precondition has a failing
  `expect_failures` run in `tests/validation.tftest.hcl`, plus a
  corresponding passing case elsewhere (the default call, or a dedicated
  rule-type test file).
- Every example is initialised, validated, linted, and scanned in CI.
- An integration suite is appropriate here — this module has no
  `prevent_destroy` and nothing bootstraps itself with it —
  `tests/integration/smoke.tftest.hcl` applies one minimal regional ACL with
  a random-suffixed name and destroys it.

## Compatibility

- Terraform `>= 1.7.0, < 2.0.0`.
- AWS provider `>= 6.35.0, < 7.0.0` (developed and tested against `6.66.0`).
- Nothing in the v1 interface is scheduled to change. Additions arrive as
  optional inputs and outputs.
