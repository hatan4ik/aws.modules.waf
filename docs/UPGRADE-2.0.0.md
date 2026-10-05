# Upgrading to 2.0.0

2.0.0 changes one input type and adds plan-time checks for two logging
requirements that AWS already enforced at apply time. No resource is
replaced, moved, or re-created by the upgrade.

## `logging_configuration.redacted_fields` is a list of header names

Before (1.x):

```hcl
logging_configuration = {
  log_destination_arn = aws_cloudwatch_log_group.waf.arn
  redacted_fields = [
    { single_header = "authorization" },
    { single_header = "cookie" },
  ]
}
```

After (2.0.0):

```hcl
logging_configuration = {
  log_destination_arn = aws_cloudwatch_log_group.waf.arn
  redacted_fields     = ["authorization", "cookie"]
}
```

The default changes from `[{ single_header = "authorization" }]` to
`["authorization"]` and still redacts the Authorization header. The rendered
`redacted_fields { single_header { name = ... } }` blocks are the same, so
the plan after migrating shows no change to
`aws_wafv2_web_acl_logging_configuration.this`.

## Logging destination checks now fail at plan, not apply

- The destination's own name (the Firehose delivery stream, CloudWatch Logs
  log group, or S3 bucket, not an S3 key prefix) must start with
  `aws-waf-logs-`.
- A Firehose or CloudWatch Logs destination must be in `us-east-1` when
  `scope = "CLOUDFRONT"`, and in `region` whenever `region` is set.

AWS already required both, so any configuration that applied on 1.x
still passes. One that never applied now fails at plan with a message
explaining why.

## Not breaking, but worth knowing

- `rate_based_rules[*].limit` now accepts values from 10 (previously 100),
  matching the current WAFv2 API range, and must be a whole number.
- `region` now accepts GovCloud and ISO region codes.
- A new advisory check, `scope_down_label_has_an_emitter`, may print a
  warning (never an error) on existing configurations. See README.md,
  "Detecting a scope-down rule that never counts".
