# see https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
# see https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name             = var.name_prefix
  azs              = ["${var.region}a", "${var.region}b", "${var.region}c"]
  cidr             = "10.0.0.0/16"
  public_subnets   = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
  private_subnets  = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
  database_subnets = ["10.0.30.0/24", "10.0.31.0/24", "10.0.32.0/24"]
  intra_subnets    = ["10.0.40.0/24", "10.0.41.0/24", "10.0.42.0/24"]
}
