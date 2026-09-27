# Minimal web ACL

The smallest working call of `aws.modules.waf`: a regional web ACL with every
default. `managed_rule_groups` defaults to `AWSManagedRulesCommonRuleSet` at
priority 1, `default_action` defaults to `allow`, and no rate-based rule, IP
set rule, custom response body, or logging is declared. Start here to see
what a web ACL needs before adding rate limiting, IP allow/block lists, or
`CLOUDFRONT` scope.

## Run

```sh
terraform init
terraform plan -var name=example-regional-acl -var region=us-east-2
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_waf"></a> [waf](#module\_waf) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | Name of the web ACL. | `string` | `"example-regional-acl"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the web ACL is created in. Use the region of the ALB, API, or other regional resource it will protect. | `string` | `"us-east-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the web ACL. Associate this with an ALB, API Gateway REST API, AppSync API, Cognito user pool, App Runner service, or Verified Access instance. |
| <a name="output_web_acl_capacity"></a> [web\_acl\_capacity](#output\_web\_acl\_capacity) | WCU capacity AWS computed for the declared rules. |
<!-- END_TF_DOCS -->
