variable "region" {
  description = "AWS region the web ACL, its IP set, and its log group are created in."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name of the web ACL."
  type        = string
  default     = "example-full-featured-acl"
}
