# CloudFront-scope web ACL

A `CLOUDFRONT`-scope web ACL, pinned to `us-east-1` — the only region AWS
reads a CloudFront web ACL from — through the module's `region` input rather
than a second, aliased AWS provider. See
[docs/DESIGN.md](../../docs/DESIGN.md#why-scope-needs-a-region-and-why-this-module-does-not-use-configuration_aliases)
in the module root for why, and `main.tf` here for the exact wiring: setting
`region = "us-east-1"` is required and validated (the plan fails otherwise),
and it does not by itself grant your credentials access to `us-east-1` — you
still need that.

## Run

```sh
terraform init
terraform plan -var name=example-cloudfront-acl
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
| <a name="input_name"></a> [name](#input\_name) | Name of the web ACL. | `string` | `"example-cloudfront-acl"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_web_acl_arn"></a> [web\_acl\_arn](#output\_web\_acl\_arn) | ARN of the web ACL. Pass this as a CloudFront distribution's web\_acl\_id. |
<!-- END_TF_DOCS -->
