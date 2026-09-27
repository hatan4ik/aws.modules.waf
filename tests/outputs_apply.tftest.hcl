# capacity, arn, and id are computed entirely by AWS and are unknown under
# command = plan; asserting on them needs command = apply with a mocked
# resource. Kept in its own file: an apply run's state would otherwise leak
# into later plan-only runs sharing the same file.

mock_provider "aws" {
  mock_resource "aws_wafv2_web_acl" {
    defaults = {
      arn      = "arn:aws:wafv2:us-east-2:123456789012:regional/webacl/example-acl/11111111-1111-1111-1111-111111111111"
      id       = "11111111-1111-1111-1111-111111111111"
      capacity = 700
    }
  }
}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "outputs_reflect_the_created_web_acl" {
  command = apply

  assert {
    condition     = output.web_acl_arn == "arn:aws:wafv2:us-east-2:123456789012:regional/webacl/example-acl/11111111-1111-1111-1111-111111111111"
    error_message = "web_acl_arn must equal the web ACL's ARN."
  }

  assert {
    condition     = output.web_acl_id == "11111111-1111-1111-1111-111111111111"
    error_message = "web_acl_id must equal the web ACL's ID."
  }

  assert {
    condition     = output.web_acl_name == "example-acl"
    error_message = "web_acl_name must equal the configured name."
  }

  assert {
    condition     = output.web_acl_capacity == 700
    error_message = "web_acl_capacity must equal the WCU capacity AWS computed for the ACL."
  }
}
