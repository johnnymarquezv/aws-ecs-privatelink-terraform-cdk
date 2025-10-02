# Shared Services Account Outputs

# S3 Artifacts
output "artifacts_s3_bucket" {
  description = "S3 bucket for build artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "artifacts_s3_bucket_arn" {
  description = "ARN of the artifacts S3 bucket"
  value       = aws_s3_bucket.artifacts.arn
}

# ECR Repository
output "ecr_repository_url" {
  description = "ECR repository URL for microservice images"
  value       = aws_ecr_repository.microservice.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.microservice.arn
}

# CodeBuild
output "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  value       = aws_codebuild_project.microservice.name
}

output "codebuild_project_arn" {
  description = "ARN of the CodeBuild project"
  value       = aws_codebuild_project.microservice.arn
}

# IAM Roles
output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild_role.arn
}

# Cross-account roles
output "monitoring_role_arn" {
  description = "ARN of the monitoring IAM role for cross-account access"
  value       = aws_iam_role.monitoring_role.arn
}

output "cicd_role_arn" {
  description = "ARN of the CI/CD IAM role for cross-account access"
  value       = aws_iam_role.cicd_role.arn
}

# Monitoring
output "prometheus_workspace_id" {
  description = "ID of the Amazon Managed Service for Prometheus workspace"
  value       = aws_prometheus_workspace.microservices.id
}

output "prometheus_workspace_arn" {
  description = "ARN of the Amazon Managed Service for Prometheus workspace"
  value       = aws_prometheus_workspace.microservices.arn
}

output "prometheus_endpoint" {
  description = "Prometheus workspace endpoint"
  value       = aws_prometheus_workspace.microservices.prometheus_endpoint
}

# CloudWatch
output "application_monitoring_log_group" {
  description = "CloudWatch log group for application monitoring"
  value       = aws_cloudwatch_log_group.application_monitoring.name
}

output "codebuild_log_group" {
  description = "CloudWatch log group for CodeBuild logs"
  value       = aws_cloudwatch_log_group.codebuild.name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.shared_services.dashboard_name}"
}

# SNS
output "deployment_notifications_topic_arn" {
  description = "ARN of the deployment notifications SNS topic"
  value       = aws_sns_topic.deployment_notifications.arn
}

# X-Ray
output "xray_sampling_rule_name" {
  description = "Name of the X-Ray sampling rule"
  value       = var.enable_xray ? aws_xray_sampling_rule.microservices[0].rule_name : null
}

# Secrets Manager
output "github_token_secret_arn" {
  description = "ARN of the GitHub token secret"
  value       = aws_secretsmanager_secret.github_token.arn
}

# Parameter Store
output "ecr_repository_uri_parameter" {
  description = "Parameter Store parameter for ECR repository URI"
  value       = aws_ssm_parameter.ecr_repository_uri.name
}

output "prometheus_workspace_id_parameter" {
  description = "Parameter Store parameter for Prometheus workspace ID"
  value       = aws_ssm_parameter.prometheus_workspace_id.name
}

output "monitoring_role_arn_parameter" {
  description = "Parameter Store parameter for monitoring role ARN"
  value       = aws_ssm_parameter.monitoring_role_arn.name
}

# Account information
output "account_id" {
  description = "Shared services account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}
