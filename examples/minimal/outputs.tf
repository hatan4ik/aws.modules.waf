output "web_acl_arn" {
  description = "ARN of the web ACL. Associate this with an ALB, API Gateway REST API, AppSync API, Cognito user pool, App Runner service, or Verified Access instance."
  value       = module.waf.web_acl_arn
}

output "web_acl_capacity" {
  description = "WCU capacity AWS computed for the declared rules."
  value       = module.waf.web_acl_capacity
}
