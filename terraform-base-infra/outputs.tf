output "vpc_id" {
  value = aws_vpc.base.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "isolated_subnet_ids" {
  value = aws_subnet.isolated[*].id
}

# Security Groups
output "base_default_security_group_id" {
  value = aws_security_group.base_default.id
}

output "base_private_security_group_id" {
  value = aws_security_group.base_private.id
}

output "vpc_endpoints_security_group_id" {
  value = aws_security_group.vpc_endpoints.id
}

# IAM Roles
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}

# CloudWatch Log Groups
output "ecs_application_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_application_logs.name
}

# VPC Endpoints
output "s3_vpc_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "dynamodb_vpc_endpoint_id" {
  value = aws_vpc_endpoint.dynamodb.id
}

output "ecr_dkr_vpc_endpoint_id" {
  value = aws_vpc_endpoint.ecr_dkr.id
}

output "ecr_api_vpc_endpoint_id" {
  value = aws_vpc_endpoint.ecr_api.id
}

output "cloudwatch_logs_vpc_endpoint_id" {
  value = aws_vpc_endpoint.cloudwatch_logs.id
}

# Cross-account resources
output "cross_account_role_arn" {
  description = "ARN of the cross-account role for resource sharing"
  value       = aws_iam_role.cross_account_role.arn
}

output "resource_share_arn" {
  description = "ARN of the AWS RAM resource share"
  value       = aws_ram_resource_share.vpc_share.arn
}

# Environment information
output "environment" {
  value = local.environment
}

output "account_id" {
  value = local.account_id
}

output "microservices_accounts" {
  value = local.microservices_accounts
}

# SSM Parameter Store outputs
output "vpc_id_parameter" {
  description = "SSM Parameter Store parameter for VPC ID"
  value       = aws_ssm_parameter.vpc_id.name
}

output "public_subnet_ids_parameter" {
  description = "SSM Parameter Store parameter for public subnet IDs"
  value       = aws_ssm_parameter.public_subnet_ids.name
}

output "private_subnet_ids_parameter" {
  description = "SSM Parameter Store parameter for private subnet IDs"
  value       = aws_ssm_parameter.private_subnet_ids.name
}

output "base_default_security_group_id_parameter" {
  description = "SSM Parameter Store parameter for base default security group ID"
  value       = aws_ssm_parameter.base_default_security_group_id.name
}

output "base_private_security_group_id_parameter" {
  description = "SSM Parameter Store parameter for base private security group ID"
  value       = aws_ssm_parameter.base_private_security_group_id.name
}

output "ecs_task_execution_role_arn_parameter" {
  description = "SSM Parameter Store parameter for ECS task execution role ARN"
  value       = aws_ssm_parameter.ecs_task_execution_role_arn.name
}

output "ecs_task_role_arn_parameter" {
  description = "SSM Parameter Store parameter for ECS task role ARN"
  value       = aws_ssm_parameter.ecs_task_role_arn.name
}

output "ecs_application_log_group_name_parameter" {
  description = "SSM Parameter Store parameter for ECS application log group name"
  value       = aws_ssm_parameter.ecs_application_log_group_name.name
}
