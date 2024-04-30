// see https://docs.aws.amazon.com/apigateway/latest/developerguide
// see https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-jwt-authorizer.html
// see https://registry.terraform.io/modules/terraform-aws-modules/apigateway-v2/aws
// see https://github.com/terraform-aws-modules/terraform-aws-apigateway-v2
module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "4.0.0"

  name = var.name_prefix

  protocol_type = "HTTP"

  create_api_domain_name = false

  integrations = {
    "$default" = {
      lambda_arn             = module.example_lambda_function.lambda_function_arn
      payload_format_version = "2.0"
    }
  }
}
