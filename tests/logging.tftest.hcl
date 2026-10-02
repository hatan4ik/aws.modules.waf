mock_provider "aws" {}

variables {
  name  = "example-acl"
  scope = "REGIONAL"
}

run "no_logging_configuration_by_default" {
  command = plan

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 0
    error_message = "No logging configuration must render when logging_configuration is not set."
  }
}

run "logging_configuration_defaults_to_redacting_authorization" {
  command = plan

  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "Setting logging_configuration must render exactly one logging configuration."
  }

  assert {
    condition     = tolist(aws_wafv2_web_acl_logging_configuration.this[0].log_destination_configs) == tolist(toset(["arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl"]))
    error_message = "log_destination_configs must wrap the single log_destination_arn."
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields) == 1 && aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields[0].single_header[0].name == "authorization"
    error_message = "redacted_fields must default to redacting the authorization header even when not asked for."
  }
}

run "logging_configuration_redacted_fields_override" {
  command = plan

  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl"
      redacted_fields     = ["cookie", "x-api-key"]
    }
  }

  assert {
    condition = (
      length(aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields) == 2 &&
      aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields[0].single_header[0].name == "cookie" &&
      aws_wafv2_web_acl_logging_configuration.this[0].redacted_fields[1].single_header[0].name == "x-api-key"
    )
    error_message = "An explicit redacted_fields list must fully replace the default, in order."
  }
}

run "logging_configuration_accepts_firehose_and_s3_destinations" {
  command = plan

  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:firehose:us-east-2:123456789012:deliverystream/aws-waf-logs-example"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "A Kinesis Data Firehose delivery stream ARN must be accepted as log_destination_arn."
  }
}

run "logging_configuration_accepts_an_s3_bucket_with_and_without_a_key_prefix" {
  command = plan

  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:s3:::aws-waf-logs-example/edge/acl"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "An S3 bucket ARN named aws-waf-logs-*, with a key prefix after it, must be accepted as log_destination_arn."
  }
}

run "logging_configuration_accepts_a_log_group_arn_with_a_trailing_wildcard" {
  command = plan

  variables {
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:aws-waf-logs-example-acl:*"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "A log group ARN in the DescribeLogGroups form (trailing :*) must be accepted as log_destination_arn."
  }
}

run "cloudfront_scope_accepts_a_us_east_1_log_group" {
  command = plan

  variables {
    scope  = "CLOUDFRONT"
    region = "us-east-1"
    logging_configuration = {
      log_destination_arn = "arn:aws:logs:us-east-1:123456789012:log-group:aws-waf-logs-example-acl"
    }
  }

  assert {
    condition     = aws_wafv2_web_acl_logging_configuration.this[0].region == "us-east-1"
    error_message = "A CLOUDFRONT-scope ACL logging to a us-east-1 log group must plan, pinned to us-east-1."
  }
}

run "cloudfront_scope_accepts_an_s3_bucket_which_carries_no_region" {
  command = plan

  variables {
    scope  = "CLOUDFRONT"
    region = "us-east-1"
    logging_configuration = {
      log_destination_arn = "arn:aws:s3:::aws-waf-logs-example"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "An S3 bucket ARN has no region segment, so the region preconditions must not reject it."
  }
}
