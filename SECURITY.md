# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan, and the impact you see.

## What counts

- A module default that weakens security: `default_action` defaulting to something other than `allow`, `managed_rule_groups` defaulting to empty, or `redacted_fields` defaulting to no redaction.
- A validation bypass: an input the module claims to reject at plan time (a malformed ARN, an out-of-bounds rate limit, a duplicate priority or rule name, an unsupported `scope_down_statement_json` shape) that reaches the provider instead.
- A region bypass: a `CLOUDFRONT`-scope web ACL created somewhere other than `us-east-1` despite the `region` precondition, or the `region` argument silently not taking effect.
- A collision the module claims to prevent going undetected: two rules sharing a name, a priority, or a CloudWatch metric name once stripped.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a managed rule group you chose to run in `count` mode, or a custom `scope_down_statement_json` composed outside this module's one supported shape) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: `default_action = allow` with `managed_rule_groups` defaulting to `AWSManagedRulesCommonRuleSet` so a bare call is still meaningfully protected, logging redaction defaulting to the Authorization header, plan-time validation of every input including the two AWS-mandated cross-rule invariants (unique priorities, unique rule names) and a module-specific third (unique CloudWatch metric names once non-alphanumeric characters are stripped), a `CLOUDFRONT`-scope ACL pinned to `us-east-1` by the resource's own `region` argument rather than left to an easily-forgotten provider alias, no data sources, and no IAM resources. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
