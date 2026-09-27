output "web_acl_arn" {
  description = "ARN of the web ACL."
  value       = module.waf.web_acl_arn
}

output "web_acl_capacity" {
  description = "WCU capacity AWS computed for the declared rules."
  value       = module.waf.web_acl_capacity
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Logs log group receiving WAF logs."
  value       = aws_cloudwatch_log_group.waf.arn
}
