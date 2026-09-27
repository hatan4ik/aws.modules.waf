# CloudFront reads a web ACL from us-east-1 only, whatever region the
# distribution's origin serves. Unlike aws.modules.acm's own CloudFront
# example, this module does not need an aliased provider passed through
# `providers = { aws = aws.us_east_1 }`: the AWS provider in the range this
# module targets (>= 6.35.0) exposes a per-resource `region` argument, so the
# module pins aws_wafv2_web_acl.this (and its logging configuration, if any)
# to `region` itself. The provider below happens to default to us-east-1 too,
# which is the natural choice next to a CloudFront distribution's other
# us-east-1 resources (its ACM certificate, for one), but that is a
# convenience, not a requirement the module depends on — try changing it to
# see that the ACL still lands in us-east-1 because `region` says so.
#
# What IS required, and what the module cannot verify on your behalf: your
# credentials must actually have access to us-east-1. See README.md and
# docs/DESIGN.md in the module root for why this module resolves the
# CLOUDFRONT/us-east-1 requirement this way instead of a second provider
# configuration.
provider "aws" {
  region = "us-east-1"
}

module "waf" {
  source = "../../"

  name   = var.name
  scope  = "CLOUDFRONT"
  region = "us-east-1"
}
