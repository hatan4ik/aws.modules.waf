# aws.modules.waf

Provisions one AWS WAFv2 web ACL per module call — the module used by both
`aws.modules.alb` (`scope = "REGIONAL"`) and `aws.modules.cloudfront`
(`scope = "CLOUDFRONT"`) to satisfy [ADR 0004](../../../../docs/adr/0004-edge-ingress-and-egress.md)'s
"WAF at each entry layer" decision. Managed rule groups, rate-based rules,
and IP set allow/block rules are declared as three typed maps; the ACL and
every rule share one visibility configuration; logging is opt-in and redacts
the Authorization header by default. It is secure by default and explicit by
declaration, creates nothing beyond the web ACL and its optional logging
configuration, and performs no data-source reads. Requires Terraform >= 1.7
and the AWS provider >= 6.35, < 7.

## Why this module

What you get from `name` and `scope`, without setting anything else:

- A meaningfully protected default. `managed_rule_groups` defaults to
  `AWSManagedRulesCommonRuleSet` at priority 1, and `default_action` defaults
  to `allow` — the standard WAF posture, where the ACL passes non-matching
  traffic through and rules block what is malicious. A bare call is not an
  empty ACL.
- Three independent rule sources, one map each. `managed_rule_groups` (AWS
  or Marketplace managed rule groups), `rate_based_rules` (request-rate
  limiting, with a bounded `scope_down_statement_json` escape hatch — see
  [Scope-down statements](#scope-down-statements)), and `ip_set_rules`
  (allow/block by an IP set you created and manage elsewhere: an IP set is
  its own lifecycle, this module does not create one). Every entry's map key
  becomes its rule name and, stripped of non-alphanumeric characters, its
  CloudWatch metric name.
- Two AWS-mandated cross-rule invariants enforced at plan time, across all
  three maps combined: every `priority` is unique, and every rule name is
  unique. A third, module-specific invariant keeps every name distinct once
  stripped for its metric name too. Every one has a precondition with a
  message naming the collision.
- A `CLOUDFRONT`-scope ACL pinned to `us-east-1` by the module itself — not
  by a provider alias the caller must remember to wire — through the AWS
  provider's own `region` argument on the resource. See
  [Scope and region](#scope-and-region).
- Logging that redacts the Authorization header even if you do not think to
  ask. `logging_configuration` is opt-in (no logging by default); once set,
  `redacted_fields` defaults to `[{ single_header = "authorization" }]`.
- Plan-time validation of every input: name and rule-key syntax, scope and
  region, every rule map's shape (priorities, actions, ARNs, JSON), custom
  response body limits, and the logging destination ARN shape.
- Advisory `check` blocks that never block: a warning when no managed rule
  group and no rate-based rule is declared (an IP set list alone gives no
  automated defense against unknown attackers), and a warning when a managed
  rule group's `override_action` is `count` (matches are logged, never
  blocked).

## Quick start

```hcl
module "waf" {
  source = "git::https://github.com/hatan4ik/aws.modules.waf.git?ref=<commit-sha>" # v1.0.0

  name  = "public-api"
  scope = "REGIONAL"

  tags = { Environment = "prod", Owner = "platform" }
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_lb.public.arn
  web_acl_arn  = module.waf.web_acl_arn
}
```

This creates a regional web ACL named `public-api` with `AWSManagedRulesCommonRuleSet`
at priority 1, `default_action = allow`, sampled requests and CloudWatch
metrics enabled, and no logging — and exposes `web_acl_arn` to associate with
an ALB, an API Gateway REST API, an AppSync API, a Cognito user pool, an App
Runner service, or a Verified Access instance.

## Architecture

```text
root (one web ACL)
├── web_acl.tf     aws_wafv2_web_acl.this: default_action, three dynamic "rule" blocks (managed/rate/IP set), custom_response_body, cross-map preconditions
├── logging.tf     aws_wafv2_web_acl_logging_configuration.this[0]: opt-in, redaction defaults
├── locals.tf      Metric-name derivation, rule-name/priority/metric-name collision detection, decoded scope-down statements
├── checks.tf      no_automated_defense, managed_rule_group_count_mode (advisory)
└── outputs.tf     web_acl_arn, web_acl_id, web_acl_name, web_acl_capacity
```

## Scope and region

`scope` has no default: `REGIONAL` (an ALB, API Gateway REST API, AppSync
API, Cognito user pool, App Runner service, or Verified Access instance, in
whatever region the resource lives) or `CLOUDFRONT` (a CloudFront
distribution; AWS reads a `CLOUDFRONT`-scope web ACL from `us-east-1` only,
whatever region the distribution's origin serves).

Terraform cannot read a provider's configured region from inside a module,
and a module cannot force a resource into a region its caller's credentials
cannot reach. This module resolves the `CLOUDFRONT` requirement with the AWS
provider's own per-resource `region` argument (available on
`aws_wafv2_web_acl` and `aws_wafv2_web_acl_logging_configuration` in the
provider range this module targets): pass `region = "us-east-1"`, and a
`lifecycle.precondition` on the web ACL rejects `scope = "CLOUDFRONT"` with
anything else. **This does not by itself grant access to `us-east-1`** — your
credentials must have it. See [`examples/cloudfront-scope`](examples/cloudfront-scope)
and [docs/DESIGN.md](docs/DESIGN.md#why-scope-needs-a-region-and-why-this-module-does-not-use-configuration_aliases)
for why this module uses that argument instead of a second, aliased provider
configuration every caller of `scope = "REGIONAL"` would otherwise have to
pass too.

`region` is optional and has no effect for `scope = "REGIONAL"` unless you
set it, in which case it pins the ACL to a specific region in a multi-region
root instead of relying on the provider's own region.

## Scope-down statements

`rate_based_rules[*].scope_down_statement_json` narrows which requests count
toward a rate limit. This module renders exactly one shape — a label match
against a label an earlier rule in the same ACL added, the AWS-recommended
way to combine a managed rule group with a rate limit:

```hcl
scope_down_statement_json = jsonencode({
  scope = "LABEL"       # or "NAMESPACE"
  key   = "awswaf:managed:aws:bot-control:signal:non_browser_user_agent"
})
```

Anything else — a byte or geo match, an IP set reference, a boolean
composition — is out of scope for this string field; compose
`aws_wafv2_web_acl` directly for that. See
[docs/DESIGN.md](docs/DESIGN.md#scope_down_statement_json-a-bounded-escape-hatch-not-a-json-compiler)
for why.

## Usage patterns

| Example | What it shows |
| --- | --- |
| [`examples/minimal`](examples/minimal) | Regional scope, every default: one managed rule group, `allow` default action, no logging. |
| [`examples/cloudfront-scope`](examples/cloudfront-scope) | `CLOUDFRONT` scope with `region = "us-east-1"`, and the reasoning a caller needs before copying it. |
| [`examples/rate-limited-api`](examples/rate-limited-api) | A managed rule group plus a rate-based rule with `FORWARDED_IP` aggregation and a `scope_down_statement_json` label match. |
| [`examples/full-featured`](examples/full-featured) | Every input at once: multiple managed rule groups (one in count mode), a rate-based rule, an IP set rule, a custom response body, and logging with a custom redacted field. |

## Security model

Posture

- `default_action` defaults to `allow`, the standard WAF posture: the ACL
  passes non-matching traffic through and rules block what is malicious.
  `block` makes the ACL default-deny.
- `managed_rule_groups` defaults to `AWSManagedRulesCommonRuleSet` at
  priority 1, so a bare call is still meaningfully protected.
- The `no_automated_defense` check warns (never blocks) when both
  `managed_rule_groups` and `rate_based_rules` are empty: an IP set
  allow/block list alone gives no automated defense against unknown
  attackers.
- The `managed_rule_group_count_mode` check warns when any managed rule
  group's `override_action` is `count`: matches are logged but never
  blocked.

Rules

- Every priority and every rule name must be unique across
  `managed_rule_groups`, `rate_based_rules`, and `ip_set_rules` combined —
  real AWS requirements, enforced here at plan time with a message naming
  the collision, instead of failing at apply.
- `rule_action_overrides` and `excluded_rules` must not name the same rule
  within one managed rule group; `excluded_rules` already forces that rule
  into count mode.
- `ip_set_rules` does not create IP sets. An IP set is its own lifecycle;
  reference one you created and manage elsewhere.

Logging

- Logging is opt-in (`logging_configuration = null` by default: nothing is
  created). Once set, `redacted_fields` defaults to redacting the
  Authorization header even if you do not think to ask.
- The logging destination (a Kinesis Data Firehose delivery stream, a
  CloudWatch Logs log group, or an S3 bucket) is created and owned by the
  caller; the module grants no permissions on it.
- The principal that applies the module needs `wafv2:CreateWebACL`,
  `wafv2:GetWebACL`, `wafv2:UpdateWebACL`, `wafv2:DeleteWebACL`,
  `wafv2:TagResource`, `wafv2:UntagResource`, `wafv2:ListTagsForResource`,
  and, when `logging_configuration` is set,
  `wafv2:PutLoggingConfiguration` and `wafv2:DeleteLoggingConfiguration` on
  the ACL, plus permission for AWS WAF to write to the logging destination
  (governed by the destination's own resource policy, not by this module).

Not created here

- IP sets, managed rule group Marketplace subscriptions, the logging
  destination, and the resource the ACL protects (an ALB, a CloudFront
  distribution, an API Gateway REST API, an AppSync API, a Cognito user
  pool, an App Runner service, a Verified Access instance). They have
  separate lifecycles and owners. The module consumes ARNs and exposes the
  web ACL's own identity.

## Lifecycle notes

- Changing `scope` or `region` in a way the CLOUDFRONT precondition would
  reject fails at plan time, before anything is touched.
- Adding, removing, or renaming an entry in any of the three rule maps adds,
  removes, or renames exactly that `rule` block; nothing else moves.
- `web_acl_capacity` is computed by AWS from the declared rules at apply
  time. Compare it against the account's WCU quota (1,500 by default,
  adjustable) before adding more rules.
- One `check` block warning does not fail an apply: `no_automated_defense`,
  `managed_rule_group_count_mode`.

## Testing

Two layers, deliberately separate:

- **Contract tests** (`tests/`, run by `make test` and by CI) use
  `mock_provider`: no credentials, nothing created. Most run under
  `command = plan`; `web_acl_capacity`, `web_acl_arn`, and `web_acl_id` are
  genuinely computed by AWS and unknown under plan, so the one test that
  asserts on them (`tests/outputs_apply.tftest.hcl`) uses `command = apply`
  with a mocked resource and lives in its own file. Every variable
  validation and resource precondition has a failing case in
  `tests/validation.tftest.hcl`.
- **Integration suites** (`tests/integration/`, run by `make integration-smoke`
  or the dispatch-only `integration` workflow) apply the module for real in
  **your** account with **your** credentials and region from the
  environment. `smoke` creates one minimal regional web ACL with a
  random-suffixed name and destroys it. See
  [tests/integration/README.md](tests/integration/README.md) for
  permissions and the GitHub environment contract.

## Design principles

- Single responsibility. The module owns one web ACL and its rules, nothing
  else. Concerns are split by file: `web_acl.tf` (the ACL, every rule, and
  the cross-map preconditions), `logging.tf` (opt-in logging), `locals.tf`
  (metric names and collision detection), `checks.tf` (advisory warnings).
- Open/closed. A new managed rule group, rate-based rule, or IP set rule
  arrives as another map entry; no mode needs the module edited.
- Liskov substitution. `web_acl_arn` means the same thing for a regional or
  a CloudFront-scope ACL: the ARN a consumer attaches to its own resource.
- Interface segregation. Each rule map's fields are independent: a managed
  rule group needs `name`; a rate-based rule needs `limit`; an IP set rule
  needs `ip_set_arn`. Nothing in one leaks into another.
- Dependency inversion. The module depends on identifiers (an IP set ARN, a
  logging destination ARN) and a region string, never on how they were
  produced, and performs no data-source reads.

The full rationale, including why `CLOUDFRONT` scope does not use a second,
aliased provider and why `scope_down_statement_json` supports exactly one
shape, is in [docs/DESIGN.md](docs/DESIGN.md).

## Compatibility and scope

- Terraform `>= 1.7.0, < 2.0.0`. AWS provider `>= 6.35.0, < 7.0.0`.
- Not created here: IP sets, the logging destination, `CUSTOM_KEYS` rate
  aggregation, and any `scope_down_statement_json` shape other than a label
  match. See [docs/DESIGN.md](docs/DESIGN.md) for the reasoning behind each.
- Nothing in the v1 interface is scheduled to change. Additions arrive as
  optional inputs and outputs.

## Versioning and releases

Releases follow semantic versioning: incompatible interface changes bump the
major version, new optional inputs and outputs bump the minor version, fixes
bump the patch version. Every release is a signed annotated tag `vX.Y.Z`.

Pin the full commit SHA of the release tag and record the tag in a comment,
so the source cannot move under you:

```hcl
module "waf" {
  source = "git::https://github.com/hatan4ik/aws.modules.waf.git?ref=<commit-sha>" # v1.0.0
}
```

The `module-release` workflow publishes an immutable GitHub release only
from a GitHub-verified, signed, annotated semantic-version tag that points
at the merged `main` revision; lightweight or unsigned tags are rejected
before anything is published. With a GitHub-associated GPG or SSH signing
key configured:

```bash
git fetch origin
git tag -s vX.Y.Z <commit> -m "vX.Y.Z"
git push origin vX.Y.Z
gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z
```

Dispatch from the tag, never from `main`: the workflow verifies that the tag
points at the revision it checked out.

All changes are listed in [CHANGELOG.md](CHANGELOG.md).

## Contributing

Development setup, the local quality gate, the test-first workflow, and the
release process are described in [CONTRIBUTING.md](CONTRIBUTING.md).
Security reports go through [SECURITY.md](SECURITY.md).

## License

Apache-2.0. See [LICENSE](LICENSE).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_logging_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_logging_configuration) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cloudwatch_metrics_enabled"></a> [cloudwatch\_metrics\_enabled](#input\_cloudwatch\_metrics\_enabled) | Whether AWS publishes CloudWatch metrics, applied to the web ACL's own visibility config and to every rule's. No per-rule override is exposed. | `bool` | `true` | no |
| <a name="input_custom_response_bodies"></a> [custom\_response\_bodies](#input\_custom\_response\_bodies) | Custom response bodies made available to this web ACL for a block or challenge custom response, keyed by the key a rule or the default action references. content\_type is TEXT\_PLAIN, TEXT\_HTML, or APPLICATION\_JSON; content is the body, 1 to 10240 bytes. Defaults to none. | <pre>map(object({<br/>    content      = string<br/>    content_type = string<br/>  }))</pre> | `{}` | no |
| <a name="input_default_action"></a> [default\_action](#input\_default\_action) | Action for a request that no rule matches. allow (default) is the standard WAF posture: the ACL passes non-matching traffic through and managed or custom rules block what is malicious. block makes the ACL default-deny: every request that should get through must match a rule with an allow action. | `string` | `"allow"` | no |
| <a name="input_ip_set_rules"></a> [ip\_set\_rules](#input\_ip\_set\_rules) | Allow or block rules referencing IP sets created and managed elsewhere (an IP set is its own lifecycle; this module does not create one), keyed by a short logical name that becomes the rule's name (unique across managed\_rule\_groups, rate\_based\_rules, and ip\_set\_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. ip\_set\_arn is the ARN of an aws\_wafv2\_ip\_set matching this ACL's own scope and region — a REGIONAL set for a REGIONAL web ACL, a CLOUDFRONT (us-east-1) set for a CLOUDFRONT web ACL; a scope mismatch is rejected by AWS at apply time, since it is not visible from the ARN alone. priority must be unique across every rule in the ACL. action is allow or block. Defaults to none. | <pre>map(object({<br/>    ip_set_arn = string<br/>    priority   = number<br/>    action     = string<br/>  }))</pre> | `{}` | no |
| <a name="input_logging_configuration"></a> [logging\_configuration](#input\_logging\_configuration) | Enables web ACL logging when set. log\_destination\_arn is a Kinesis Data Firehose delivery stream, CloudWatch Logs log group, or S3 bucket ARN that the caller creates and owns; the module grants no permissions and creates no destination. redacted\_fields lists request fields AWS omits from the logged payload, defaulting to the Authorization header even if the caller does not think to ask; the only field this module can redact is a named header (single\_header) — redact the method, query string, URI path, or body by composing aws\_wafv2\_web\_acl\_logging\_configuration directly. Defaults to no logging. | <pre>object({<br/>    log_destination_arn = string<br/>    redacted_fields = optional(list(object({<br/>      single_header = optional(string)<br/>    })), [{ single_header = "authorization" }])<br/>  })</pre> | `null` | no |
| <a name="input_managed_rule_groups"></a> [managed\_rule\_groups](#input\_managed\_rule\_groups) | AWS or Marketplace managed rule groups, keyed by a short logical name that becomes the rule's name (unique across managed\_rule\_groups, rate\_based\_rules, and ip\_set\_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. name is the managed rule group's own AWS name (for example AWSManagedRulesCommonRuleSet); vendor\_name defaults to AWS. priority orders evaluation and must be unique across every rule in the ACL — AWS evaluates lower numbers first. override\_action is none (the group's own per-rule actions apply) or count (every rule in the group only counts a match, never blocks; see the managed\_rule\_group\_count\_mode check). excluded\_rules names rules within the group to force into count mode individually, the modern equivalent of the deprecated per-group excluded\_rule; rule\_action\_overrides maps a rule name to allow, block, count, captcha, or challenge for finer per-rule control. A rule name must not appear in both. version pins a specific managed rule group version; omit it to track AWS's default (usually latest) version. Defaults to AWS's Core rule set alone at priority 1, so a bare call is still meaningfully protected. | <pre>map(object({<br/>    name                  = string<br/>    vendor_name           = optional(string, "AWS")<br/>    priority              = number<br/>    override_action       = optional(string, "none")<br/>    excluded_rules        = optional(set(string), [])<br/>    rule_action_overrides = optional(map(string), {})<br/>    version               = optional(string)<br/>  }))</pre> | <pre>{<br/>  "common": {<br/>    "name": "AWSManagedRulesCommonRuleSet",<br/>    "priority": 1<br/>  }<br/>}</pre> | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the WAFv2 web ACL. Also the base for the CloudWatch metric names of the ACL and every rule, which AWS restricts to letters and digits: each metric name is derived by stripping every other character, so every name and rule key must contain at least one letter or digit and stay distinct after stripping (a precondition names a collision). | `string` | n/a | yes |
| <a name="input_rate_based_rules"></a> [rate\_based\_rules](#input\_rate\_based\_rules) | Rate-based rules, keyed by a short logical name that becomes the rule's name (unique across managed\_rule\_groups, rate\_based\_rules, and ip\_set\_rules) and, stripped of non-alphanumeric characters, its CloudWatch metric name. limit is the request count in a trailing 5-minute window that trips the rule, between AWS's documented bounds of 100 and 2,000,000,000. aggregate\_key\_type buckets requests by source IP (IP, the default) or by the IP found in a trusted X-Forwarded-For header with a MATCH fallback, so a request missing the header still counts (FORWARDED\_IP); AWS's CUSTOM\_KEYS aggregation is out of scope. priority must be unique across every rule in the ACL. action is block (default), count, captcha, or challenge. scope\_down\_statement\_json narrows which requests count toward the limit; this module renders exactly one shape, a label match against a label an earlier rule in the same ACL added — {"scope": "LABEL", "key": "<label>"} or {"scope": "NAMESPACE", "key": "<namespace>"}. Anything more elaborate (byte or geo match, IP set reference, boolean compositions) is out of scope for this string escape hatch; compose aws\_wafv2\_web\_acl directly for that. Defaults to none, so no rate limiting applies unless declared. | <pre>map(object({<br/>    limit                     = number<br/>    aggregate_key_type        = optional(string, "IP")<br/>    priority                  = number<br/>    action                    = optional(string, "block")<br/>    scope_down_statement_json = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_region"></a> [region](#input\_region) | Region this web ACL, and its logging configuration when logging\_configuration is set, are created in. Passed straight through as the resource's own region argument, so the result does not depend on which region the caller's default provider happens to be configured for. Required and must be "us-east-1" when scope = "CLOUDFRONT" — the only region WAFv2 accepts a CLOUDFRONT-scope web ACL from. Terraform cannot read a provider's configured region from inside a module and cannot force a resource into a region the caller's credentials cannot reach, so this is a caller-declared value the module both validates and applies: setting region = "us-east-1" here does not by itself grant access to that region, your credentials must have it too. Optional and unused by default for scope = "REGIONAL" (the ACL takes the provider's own region); set it there only to pin the ACL to a specific region in a multi-region root. | `string` | `null` | no |
| <a name="input_sampled_requests_enabled"></a> [sampled\_requests\_enabled](#input\_sampled\_requests\_enabled) | Whether AWS samples matched requests, applied to the web ACL's own visibility config and to every rule's. No per-rule override is exposed. | `bool` | `true` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Where the web ACL is enforced: REGIONAL (an Application Load Balancer, API Gateway REST API, AppSync GraphQL API, Cognito user pool, App Runner service, or Verified Access instance) or CLOUDFRONT (a CloudFront distribution — AWS reads CLOUDFRONT-scope web ACLs from us-east-1 only, whatever region the distribution itself serves; see region). No default: the choice is deliberate, never inherited. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the web ACL. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the web ACL. Attach it to an ALB, CloudFront distribution, or other supported resource. |
| <a name="output_web_acl_capacity"></a> [web\_acl\_capacity](#output\_web\_acl\_capacity) | Web ACL capacity units (WCU) consumed by the declared rules, as computed by AWS. Compare against the account's WCU quota (1,500 by default, adjustable) before adding more rules. |
| <a name="output_web_acl_id"></a> [web\_acl\_id](#output\_web\_acl\_id) | ID of the web ACL. |
| <a name="output_web_acl_name"></a> [web\_acl\_name](#output\_web\_acl\_name) | Name of the web ACL. |
<!-- END_TF_DOCS -->
