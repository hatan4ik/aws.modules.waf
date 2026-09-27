# Full-featured web ACL

Every input at once, in one regional web ACL: two managed rule groups (the
Common rule set, and Bot Control run in `count` mode with one excluded rule —
deliberately triggering the `managed_rule_group_count_mode` advisory check,
which warns without failing the plan), a rate-based rule, an IP set allow
rule against a small `aws_wafv2_ip_set` the example creates for itself (the
module does not create IP sets), a custom JSON response body, and logging to
a CloudWatch Logs log group with the Authorization header and cookies
redacted.

## Run

```sh
terraform init
terraform plan -var name=example-full-featured-acl -var region=us-east-2
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_waf"></a> [waf](#module\_waf) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.waf](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_wafv2_ip_set.known_partners](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_ip_set) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the web ACL. | `string` | `"example-full-featured-acl"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the web ACL, its IP set, and its log group are created in. | `string` | `"us-east-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | ARN of the CloudWatch Logs log group receiving WAF logs. |
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the web ACL. |
| <a name="output_web_acl_capacity"></a> [web\_acl\_capacity](#output\_web\_acl\_capacity) | WCU capacity AWS computed for the declared rules. |
<!-- END_TF_DOCS -->
