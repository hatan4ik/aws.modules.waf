# Logging is opt-in: nothing is created unless logging_configuration is set,
# and the destination (Firehose, CloudWatch Logs, or S3) is created and owned
# by the caller. Redaction defaults to the Authorization header even when the
# caller does not think to ask.

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.logging_configuration == null ? 0 : 1

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = toset([var.logging_configuration.log_destination_arn])
  region                  = var.region

  dynamic "redacted_fields" {
    for_each = local.redacted_fields

    content {
      single_header {
        name = redacted_fields.value
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.scope != "CLOUDFRONT" || contains(["", "us-east-1"], local.logging_destination_region)
      error_message = "logging_configuration.log_destination_arn must be in us-east-1 when scope = \"CLOUDFRONT\": AWS WAF only delivers a CLOUDFRONT-scope web ACL's logs to a Firehose delivery stream or CloudWatch Logs log group in us-east-1. Got region \"${local.logging_destination_region}\"."
    }

    precondition {
      condition     = var.region == null || contains(["", var.region], local.logging_destination_region)
      error_message = "logging_configuration.log_destination_arn must be in the web ACL's own region: AWS WAF only delivers logs to a Firehose delivery stream or CloudWatch Logs log group in the same region as the web ACL. region is \"${coalesce(var.region, "unset")}\", the destination is in \"${local.logging_destination_region}\"."
    }
  }
}
