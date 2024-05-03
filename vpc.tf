# see https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
# see https://github.com/terraform-aws-modules/terraform-aws-vpc
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name             = var.name_prefix
  azs              = ["${var.region}a", "${var.region}b"]
  cidr             = "10.0.0.0/16"
  public_subnets   = ["10.0.10.0/24", "10.0.11.0/24"]
  private_subnets  = ["10.0.20.0/24", "10.0.21.0/24"]
  database_subnets = ["10.0.30.0/24", "10.0.31.0/24"]
  intra_subnets    = ["10.0.40.0/24", "10.0.41.0/24"]
}

# see https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest/submodules/vpc-endpoints
# see https://github.com/terraform-aws-modules/terraform-aws-vpc/blob/master/modules/vpc-endpoints
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "5.8.1"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      security_group_ids  = [aws_security_group.aws_secretsmanager.id]
      subnet_ids          = module.vpc.intra_subnets
      tags = {
        Name = "${var.name_prefix}-aws-secretsmanager"
      }
    }
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "aws_secretsmanager" {
  vpc_id = module.vpc.vpc_id
  name   = "aws-secretsmanager"
  tags = {
    Name = "${var.name_prefix}-aws-secretsmanager"
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule
resource "aws_vpc_security_group_ingress_rule" "aws_secretsmanager_intra" {
  for_each = { for i, cidr_block in module.vpc.intra_subnets_cidr_blocks : module.vpc.azs[i] => cidr_block }

  security_group_id = aws_security_group.aws_secretsmanager.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  tags = {
    Name = "${var.name_prefix}-aws-secretsmanager-intra-${each.key}"
  }
}
