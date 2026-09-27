variable "region" {
  description = "AWS region the web ACL is created in. Use the region of the API it will protect."
  type        = string
  default     = "us-east-2"
}

variable "name" {
  description = "Name of the web ACL."
  type        = string
  default     = "example-rate-limited-api"
}
