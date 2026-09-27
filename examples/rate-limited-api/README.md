# Rate-limited API

A regional web ACL for an API: the Common rule set plus Bot Control, and two
rate-based rules layered on top. `api_traffic` limits general traffic by the
IP found in a trusted `X-Forwarded-For` header (`aggregate_key_type =
"FORWARDED_IP"`, which the module renders with a fixed `header_name` and a
fail-closed `MATCH` fallback). `suspected_bots` uses
`scope_down_statement_json` to apply a much lower limit to requests Bot
Control already labeled `non_browser_user_agent` — the AWS-recommended way to
combine a managed rule group with a rate limit, and the one shape this
module's `scope_down_statement_json` renders. See
[docs/DESIGN.md](../../docs/DESIGN.md#scope_down_statement_json-a-bounded-escape-hatch-not-a-json-compiler)
for why it renders only this shape.

## Run

```sh
terraform init
terraform plan -var name=example-rate-limited-api -var region=us-east-2
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
| <a name="input_name"></a> [name](#input\_name) | Name of the web ACL. | `string` | `"example-rate-limited-api"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the web ACL is created in. Use the region of the API it will protect. | `string` | `"us-east-2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the web ACL. |
| <a name="output_web_acl_capacity"></a> [web\_acl\_capacity](#output\_web\_acl\_capacity) | WCU capacity AWS computed for the declared rules. |
<!-- END_TF_DOCS -->
