output "web_acl_arn" {
  description = "ARN of the web ACL. Pass this as a CloudFront distribution's web_acl_id."
  value       = module.waf.web_acl_arn
}
