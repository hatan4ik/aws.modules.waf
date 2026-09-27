# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use
placeholder ARNs and the AWS documentation account `123456789012` on purpose:
they prove the module's interface and rendering, not that AWS accepts it.
These suites prove the latter.

Nothing here is tied to an account, region, or a pre-existing resource. The
web ACL under test gets a name suffixed by a hash of the current time (not a
`random_id` resource: pulling in the `hashicorp/random` provider for a test
directory grafts it into the repository root's committed `.terraform.lock.hcl`
the next time someone runs a plain `terraform init` there, which is exactly
the kind of accidental diff this suite is designed not to cause). Credentials
and the region come from the environment. A suite that ever needs a fixture
keeps it in `setup/`, which the policy scans exclude (`.checkov.yml`,
`trivy.yaml`).

| Suite | What it proves | Needs | Typical time |
| --- | --- | --- | --- |
| `smoke.tftest.hcl` | A minimal `REGIONAL` web ACL with the module's default managed rule group is accepted by the real API, gets a real ARN and a positive computed WCU capacity, and carries the requested name and tags; the ACL is deleted at the end of the run. | credentials, region | about a minute |

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json)
(replace `<ACCOUNT_ID>`): `wafv2:CreateWebACL`, which AWS does not let IAM
scope to a not-yet-existing resource, and the get, update, delete, and
tagging actions scoped to web ACLs named `waf-smoke-*`. Nothing else is
touched.

`terraform test` runs `tests/` only by default, so this suite never runs in
the credential-free quality pipeline.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region the web ACL is created in. |

Dispatch with `gh workflow run integration.yml -f suite=smoke`. Protect the
environment with required reviewers so a run cannot be started from a pull
request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.waf:environment:integration`.
