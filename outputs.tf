output "example_url" {
  value = module.api_gateway.apigatewayv2_api_api_endpoint
}

output "example_docdb_master_password" {
  value     = random_password.example_docdb_master_password.result
  sensitive = true
}

output "example_docdb_master_connection_string" {
  value       = local.example_docdb_master_connection_string
  description = "NB you cannot access this outside of the VPC."
  sensitive   = true
}
