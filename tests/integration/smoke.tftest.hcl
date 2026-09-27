# Integration suite: real apply in the caller's own account.
#
# Requires AWS credentials and a region from the environment (for example
# AWS_PROFILE and AWS_REGION, or the OIDC role assumed by the integration
# workflow). Creates one minimal regional web ACL with a name suffixed by a
# hash of the current time (avoiding a hashicorp/random dependency, which
# would graft itself into the root's committed provider lock file), asserts
# what the real API reports, and destroys it at the end of the file. WAFv2
# web ACLs are not billed per-request in a way a one-minute smoke test would
# notice, and nothing here has a minimum retention period, so nothing lingers
# and nothing meaningfully costs anything.
#
# Run: terraform init -backend=false -test-directory=tests/integration
#      terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl

provider "aws" {}

run "smoke" {
  variables {
    name  = "waf-smoke-${substr(md5(timestamp()), 0, 10)}"
    scope = "REGIONAL"

    tags = {
      IntegrationTest = "aws.modules.waf"
      Disposable      = "true"
    }
  }

  assert {
    condition     = startswith(output.web_acl_arn, "arn:") && output.web_acl_id != null
    error_message = "The web ACL must be created with a real ARN and ID."
  }

  assert {
    condition     = output.web_acl_name == var.name
    error_message = "web_acl_name must equal the requested name."
  }

  assert {
    condition     = output.web_acl_capacity > 0
    error_message = "AWS must report a positive WCU capacity for the default managed rule group."
  }

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "REGIONAL" && length(aws_wafv2_web_acl.this.rule) == 1
    error_message = "The real API must accept the module's default single managed rule group."
  }

  assert {
    condition     = aws_wafv2_web_acl.this.tags["IntegrationTest"] == "aws.modules.waf" && aws_wafv2_web_acl.this.tags["Disposable"] == "true"
    error_message = "Tags must be applied to the real resource."
  }
}
