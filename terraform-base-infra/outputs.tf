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
  value = aws_iam_role.cross_account_role.arn
}

output "resource_share_arn" {
  value = aws_ram_resource_share.vpc_share.arn
}

output "microservice_vpc_endpoint_service_id" {
  value = aws_vpc_endpoint_service.microservice.id
}

output "microservice_load_balancer_arn" {
  value = aws_lb.microservice.arn
}

output "microservice_target_group_arn" {
  value = aws_lb_target_group.microservice.arn
}

# Environment information
output "environment" {
  value = var.environment
}

output "account_id" {
  value = var.account_id
}

output "microservices_accounts" {
  value = var.microservices_accounts
}
