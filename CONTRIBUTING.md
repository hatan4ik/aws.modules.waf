# Contributing

Thank you for improving `aws.modules.waf`. This guide covers the toolchain, the local quality gate, how features are tested and where they belong, commit and pull request conventions, and how releases are cut.

## Development setup

The module targets Terraform `>= 1.7.0, < 2.0.0` and is developed against 1.7.5, the version the consuming platform pins. Install the toolchain:

| Tool | Purpose | Install |
| --- | --- | --- |
| [tfenv](https://github.com/tfutils/tfenv) | Pin the Terraform version | `tfenv install 1.7.5 && tfenv use 1.7.5` |
| [tflint](https://github.com/terraform-linters/tflint) | Lint with the Terraform and AWS rulesets configured in `.tflint.hcl` | `brew install tflint && tflint --init` |
| [terraform-docs](https://terraform-docs.io) v0.20.0 | Generate the inputs and outputs tables in every README. Pinned to the version bundled by the CI docs action; newer releases change table formatting and fail the drift check (`make docs` refuses other versions). | Download the v0.20.0 binary from the [releases page](https://github.com/terraform-docs/terraform-docs/releases/tag/v0.20.0) |
| [checkov](https://www.checkov.io) | Static security policy | `pip install checkov` |
| [trivy](https://trivy.dev) | Misconfiguration scanning | `brew install trivy` |
| [pre-commit](https://pre-commit.com) | Run the gate on every commit | `pip install pre-commit && pre-commit install` |

Clone, initialise without a backend, and run the gate once to confirm the setup:

```sh
terraform init -backend=false -input=false
make check
```

Use a private plugin cache (`export TF_PLUGIN_CACHE_DIR=<somewhere-not-shared>`) if you work on more than one of this account's modules at once; a shared cache corrupted by two concurrent `terraform init` runs surfaces as `exec format error` or checksum mismatches that have nothing to do with your change.

## Integration suites

`tests/integration/` holds credential-driven suites that apply the module for real and destroy everything afterwards. They are never part of `make check` or the quality pipeline. Run them against your own account before a release that touches resource behaviour:

```bash
export AWS_PROFILE=<profile> AWS_REGION=<region>
make integration-smoke   # about a minute; one minimal regional web ACL, created and deleted
```

Add a suite when a feature's correctness depends on the AWS API rather than on rendering (for example a new rule shape or a logging destination type). Keep every value derived from the environment or from disposable fixtures the suite creates, and never reference a real IP set, logging destination, or account. A suite that needs fixtures keeps them in `tests/integration/setup`, which the policy scans exclude.

## The local gate

`make check` is the default target and the same gate CI runs. It stops at the first failing target and must pass before you open a pull request.

| Target | What it runs |
| --- | --- |
| `make fmt` | `terraform fmt -check -recursive -diff` from the repository root. `make fmt-fix` rewrites the files instead. |
| `make validate` | `make init` (`terraform init -backend=false`) followed by `terraform validate` in the root and every example directory. |
| `make lint` | `tflint --init` and then `tflint` in every directory with the root `.tflint.hcl`: documented and typed variables, documented outputs, snake_case naming, no unused declarations, pinned required versions and providers. |
| `make test` | `terraform test` in the root. No credentials are needed. |
| `make lock` | Refresh the committed root `.terraform.lock.hcl` with hashes for linux and macOS on amd64 and arm64 after changing the provider constraint. CI runs `terraform init` before the docs drift check, so a lock file missing the Linux hash gets rewritten and fails that check. |
| `make docs` | `terraform-docs -c .terraform-docs.yml` in every directory, regenerating the tables between the `BEGIN_TF_DOCS` and `END_TF_DOCS` markers. Run it after touching any variable or output. |
| `make docs-check` | The same in `--output-check` mode: fails when a README is out of date. This is the variant `make check` and CI run. |
| `make security` | `checkov -d . --framework terraform`, and `trivy config --severity HIGH,CRITICAL` when trivy is on the PATH. A skip needs an inline `checkov:skip=` comment with a reason on the resource it concerns. |
| `make check` | `fmt`, `validate`, `lint`, `test`, `docs-check`, `security`, in that order. |

## Test-first workflow

Every behaviour in this module is pinned by a test before it is implemented. Write the failing `run` block first, then the code, then run `make test`.

- Tests live in `tests/*.tftest.hcl`, one file per concern: `defaults`, `managed_rule_groups`, `rate_based_rules`, `ip_set_rules`, `logging`, `cloudfront_scope`, `checks`, `validation` (every variable validation and cross-map precondition), and `outputs_apply` (the genuinely AWS-computed outputs). Each file starts with `mock_provider "aws" {}` and a `variables` block holding a valid baseline; each `run` overrides only what it exercises.
- Use `command = plan` wherever possible. Nothing here talks to AWS, so tests run in seconds and in CI without credentials. `web_acl_capacity`, `web_acl_arn`, and `web_acl_id` are computed by AWS and unknown under plan; the one test asserting on them uses `command = apply` with a `mock_resource "aws_wafv2_web_acl" { defaults = { ... } }` default and lives in its own file — an `apply` run's state would otherwise leak into a later `plan` run sharing the same file.
- `rule` and `custom_response_body` are set-nested blocks: `aws_wafv2_web_acl.this.rule[0]` is invalid. Either restrict the rule maps under test to one homogeneous shape (so `anytrue([for r in aws_wafv2_web_acl.this.rule : r.field == ...])` never evaluates a field a different rule's statement type does not have — `&&` does not short-circuit in Terraform 1.7, so a mixed-shape iteration raises "Invalid index" instead of returning `false`), or filter by name first (`[for r in ... : r if r.name == "x"]`) before indexing into the single result.
- Validations are tested with `expect_failures`. Point it at the object that carries the check: `[var.managed_rule_groups]` for a variable validation, `[aws_wafv2_web_acl.this]` for a cross-map precondition, `[check.no_automated_defense]` for a `check` block. A run with `expect_failures` passes only if exactly those objects fail; add a positive run alongside so the happy path is covered too. A `check` block failure aborts a `terraform test` run just like a hard validation failure unless it is named in `expect_failures` — it only "never blocks" a plain `plan`/`apply` outside of tests.
- `||` and `&&` do not short-circuit in Terraform 1.7. Both operands are always evaluated, so `var.x == null || var.x.field > 0` fails when `x` is null, and `for` expressions iterating a mixed collection can throw mid-loop even inside an `if` filter clause. Guard with a conditional instead: `var.x == null ? true : var.x.field > 0` — the conditional operator's branches, unlike `&&`/`||`, are evaluated lazily.
- An "empty set" check must use `length(x) == 0`, not `x == toset([])`: `setsubtract` and similar functions can return an empty set with a concrete element type that compares unequal to a bare `toset([])` literal (a different, less specific type), even though both are conceptually empty.
- Keep assertion `error_message` text a statement of the guaranteed behaviour. It becomes the documentation of the contract when a test fails.

## Where to add a feature

The module has no submodules; concerns are split by file, and each file has one reason to change.

| Concern | Lives in |
| --- | --- |
| A new field on an existing rule map, or a new rule map | `variables.tf` with a description, type, and validation; `web_acl.tf` to render it inside the matching `dynamic "rule"` block. |
| Metric-name derivation, collision detection, decoded scope-down statements | `locals.tf`. |
| The web ACL, its rules, and cross-map invariants | `web_acl.tf`, as `lifecycle.precondition`s on `aws_wafv2_web_acl.this`. |
| Logging | `logging.tf`. |
| Advisory, non-blocking warnings | `checks.tf`. |
| Outputs | `outputs.tf`; every output has a description, and a genuinely computed one is asserted in `tests/outputs_apply.tftest.hcl`. |

Rules that apply everywhere: no data sources (derive from inputs and the provider's region), every variable has a description, a type, and a validation where a wrong value would otherwise fail at apply time, every output has a description, defaults are the secure choice, and a rule map's own fields are rejected when they do not apply rather than silently ignored.

## Commits

Use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The scope is the file or concern the change touches.

```text
feat(rate_based_rules): support CUSTOM_KEYS aggregation
fix(locals): strip a leading digit correctly when deriving a metric name
docs: explain the region argument versus a provider alias
test(logging): cover an S3 bucket ARN as the destination
feat!: rename ip_set_rules.action to ip_set_rules.effect
```

Append `!` after the type or scope for a breaking change and add a `BREAKING CHANGE:` footer explaining what consumers must do. Breaking changes ship only in a major release with an entry in a new `docs/UPGRADE-<major>.md`.

## Pull request checklist

- [ ] `make check` passes locally.
- [ ] New behaviour has a test; changed validations have both a passing and an `expect_failures` run.
- [ ] Variables and outputs have descriptions; `make docs` regenerated the README tables.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]` in the right category.
- [ ] Breaking changes carry `!`, a `BREAKING CHANGE:` footer, and a new `docs/UPGRADE-<major>.md`.
- [ ] Examples still initialise and validate; a new feature worth showing has an example.
- [ ] No data sources, no hard-coded account, region, or partition, no new defaults that weaken security.

## Release process

Releases are cut by maintainers.

1. Move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading, add its compare link, and merge that change to `main`.
2. Create a signed annotated tag on the merge commit. The signing key must be registered with GitHub so the tag shows as Verified:

   ```sh
   git tag -s vX.Y.Z -m "aws.modules.waf vX.Y.Z"
   git push origin vX.Y.Z
   ```

3. Dispatch the `module-release` workflow (`.github/workflows/module-release.yml`) from the tag with `release_tag = vX.Y.Z`: `gh workflow run module-release.yml --ref vX.Y.Z -f release_tag=vX.Y.Z`. It verifies the signed tag, formatting, validation, tests, and generated docs, then publishes the GitHub release. Never dispatch it from `main`: the workflow checks that the tag points at the revision it checked out, and a maintenance release of an older line is cut from that line's commit.
4. Announce the release with the commit SHA. Consumers pin that SHA, not the tag:

   ```hcl
   source = "git::https://github.com/hatan4ik/aws.modules.waf.git?ref=<commit-sha>" # vX.Y.Z
   ```

Tags are never moved or deleted once published. A bad release is followed by a new patch release.
