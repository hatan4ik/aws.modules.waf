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
      dynamic "single_header" {
        for_each = redacted_fields.value.single_header == null ? [] : [redacted_fields.value.single_header]

        content {
          name = single_header.value
        }
      }
    }
  }
}
