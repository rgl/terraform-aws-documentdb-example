# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
data "aws_caller_identity" "current" {}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecr_authorization_token
data "aws_ecr_authorization_token" "current" {}

locals {
  source_path = "example"
  source_tag  = sha1(join("", [for f in sort(fileset(path.module, "${local.source_path}/*")) : filesha1(f)]))
}

# see https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws/latest/submodules/docker-build
# see https://github.com/terraform-aws-modules/terraform-aws-lambda
module "example_docker_image" {
  source  = "terraform-aws-modules/lambda/aws//modules/docker-build"
  version = "7.4.0"

  create_ecr_repo = true
  ecr_repo        = var.name_prefix

  use_image_tag = true
  image_tag     = local.source_tag
  source_path   = local.source_path
}

# see https://registry.terraform.io/modules/terraform-aws-modules/lambda/aws
# see https://github.com/terraform-aws-modules/terraform-aws-lambda
module "example_lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "7.4.0"

  vpc_subnet_ids         = module.vpc.intra_subnets
  vpc_security_group_ids = [aws_security_group.example_lambda_function.id]
  attach_network_policy  = true

  timeout = 15 # [second]. default is 3s. max is 900s (15m).

  function_name  = var.name_prefix
  create_package = false
  publish        = true

  image_uri    = module.example_docker_image.image_uri
  package_type = "Image"

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.example_docdb_master_secret.arn
      },
    ]
  })

  environment_variables = {
    EXAMPLE_DOCDB_CONNECTION_STRING_SECRET_REGION = var.region
    EXAMPLE_DOCDB_CONNECTION_STRING_SECRET_ID     = aws_secretsmanager_secret.example_docdb_master_secret.name
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group
resource "aws_security_group" "example_lambda_function" {
  vpc_id      = module.vpc.vpc_id
  name        = "example-lambda-function"
  description = "Example Lambda Function"
  tags = {
    Name = "${var.name_prefix}-example-lambda-function"
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule
resource "aws_vpc_security_group_egress_rule" "example_lambda_function_mongo" {
  for_each = { for i, cidr_block in module.vpc.database_subnets_cidr_blocks : module.vpc.azs[i] => cidr_block }

  security_group_id = aws_security_group.example_lambda_function.id
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  from_port         = local.example_docdb_port
  to_port           = local.example_docdb_port
  tags = {
    Name = "${var.name_prefix}-docdb-mongo-${each.key}"
  }
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule
resource "aws_vpc_security_group_egress_rule" "example_lambda_function_vpc" {
  security_group_id = aws_security_group.example_lambda_function.id
  ip_protocol       = "all"
  cidr_ipv4         = module.vpc.vpc_cidr_block
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}
