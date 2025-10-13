# Transit Gateway outputs
output "transit_gateway_id" {
  description = "ID of the Transit Gateway for cross-account connectivity"
  value       = aws_ec2_transit_gateway.main.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.main.arn
}

output "transit_gateway_route_table_id" {
  description = "ID of the Transit Gateway route table"
  value       = aws_ec2_transit_gateway_route_table.main.id
}

# Cross-account resources
output "cross_account_role_arn" {
  description = "ARN of the cross-account role for resource access"
  value       = aws_iam_role.cross_account_role.arn
}

output "transit_gateway_sharing_role_arn" {
  description = "ARN of the Transit Gateway sharing role"
  value       = aws_iam_role.transit_gateway_sharing_role.arn
}

output "resource_share_arn" {
  description = "ARN of the AWS RAM resource share for Transit Gateway"
  value       = aws_ram_resource_share.transit_gateway_share.arn
}

# Environment information
output "environment" {
  description = "Current environment"
  value       = local.environment
}

output "account_id" {
  description = "Networking account ID"
  value       = local.account_id
}

output "microservices_accounts" {
  description = "List of microservices account IDs"
  value       = local.microservices_accounts
}

# CloudWatch Logs
output "cross_account_log_group_name" {
  description = "Name of the cross-account monitoring log group"
  value       = aws_cloudwatch_log_group.cross_account_logs.name
}

# SSM Parameter Store outputs
output "transit_gateway_id_parameter" {
  description = "SSM Parameter Store parameter for Transit Gateway ID"
  value       = aws_ssm_parameter.transit_gateway_id.name
}

output "transit_gateway_route_table_id_parameter" {
  description = "SSM Parameter Store parameter for Transit Gateway route table ID"
  value       = aws_ssm_parameter.transit_gateway_route_table_id.name
}

output "cross_account_role_arn_parameter" {
  description = "SSM Parameter Store parameter for cross-account role ARN"
  value       = aws_ssm_parameter.cross_account_role_arn.name
}

output "environment_parameter" {
  description = "SSM Parameter Store parameter for environment"
  value       = aws_ssm_parameter.environment.name
}

output "networking_account_id_parameter" {
  description = "SSM Parameter Store parameter for networking account ID"
  value       = aws_ssm_parameter.networking_account_id.name
}

output "microservices_accounts_parameter" {
  description = "SSM Parameter Store parameter for microservices accounts"
  value       = aws_ssm_parameter.microservices_accounts.name
}