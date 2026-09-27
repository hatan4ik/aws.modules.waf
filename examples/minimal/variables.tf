variable "region" {
  description = "AWS region the web ACL is created in. Use the region of the ALB, API, or other regional resource it will protect."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name of the web ACL."
  type        = string
  default     = "example-regional-acl"
}
