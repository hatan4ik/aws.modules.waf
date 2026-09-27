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
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:/aws/waf/example-acl"
    }
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "Setting logging_configuration must render exactly one logging configuration."
  }

  assert {
    condition     = tolist(aws_wafv2_web_acl_logging_configuration.this[0].log_destination_configs) == tolist(toset(["arn:aws:logs:us-east-2:123456789012:log-group:/aws/waf/example-acl"]))
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
      log_destination_arn = "arn:aws:logs:us-east-2:123456789012:log-group:/aws/waf/example-acl"
      redacted_fields = [
        { single_header = "cookie" },
        { single_header = "x-api-key" },
      ]
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
