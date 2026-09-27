provider "aws" {
  region = var.region
}

module "waf" {
  source = "../../"

  name  = var.name
  scope = "REGIONAL"
}
