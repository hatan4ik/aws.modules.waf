mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "CLOUDFRONT"
}

run "cloudfront_scope_requires_region_us_east_1" {
  command = plan

  expect_failures = [aws_wafv2_web_acl.this]
}

run "cloudfront_scope_with_wrong_region_still_fails" {
  command = plan

  variables {
    region = "us-west-2"
  }

  expect_failures = [aws_wafv2_web_acl.this]
}

run "cloudfront_scope_with_region_us_east_1_succeeds" {
  command = plan

  variables {
    region = "us-east-1"
  }

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "CLOUDFRONT" && aws_wafv2_web_acl.this.region == "us-east-1"
    error_message = "scope = CLOUDFRONT with region = us-east-1 must render a CLOUDFRONT web ACL pinned to us-east-1 via the resource's own region argument."
  }
}

run "regional_scope_does_not_require_region" {
  command = plan

  variables {
    scope = "REGIONAL"
  }

  assert {
    condition     = aws_wafv2_web_acl.this.scope == "REGIONAL"
    error_message = "scope = REGIONAL must not require region."
  }
}

run "regional_scope_can_still_pin_a_region" {
  command = plan

  variables {
    scope  = "REGIONAL"
    region = "eu-west-1"
  }

  assert {
    condition     = aws_wafv2_web_acl.this.region == "eu-west-1"
    error_message = "REGIONAL scope must accept an explicit region to pin the ACL in a multi-region root."
  }
}
