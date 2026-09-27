output "web_acl_arn" {
  description = "ARN of the web ACL. Attach it to an ALB, CloudFront distribution, or other supported resource."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the web ACL."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the web ACL."
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_capacity" {
  description = "Web ACL capacity units (WCU) consumed by the declared rules, as computed by AWS. Compare against the account's WCU quota (1,500 by default, adjustable) before adding more rules."
  value       = aws_wafv2_web_acl.this.capacity
}
