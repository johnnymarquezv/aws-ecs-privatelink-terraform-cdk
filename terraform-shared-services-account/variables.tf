variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "Current AWS account ID (Shared Services Account)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "organization_accounts" {
  description = "Map of organization account IDs"
  type = object({
    root_account_id         = string
    security_account_id     = string
    networking_account_id   = string
    provider_account_ids    = list(string)
    consumer_account_ids    = list(string)
  })
}

variable "artifacts_s3_bucket_name" {
  description = "S3 bucket name for build artifacts"
  type        = string
}

variable "container_registry_name" {
  description = "ECR repository name for container images"
  type        = string
  default     = "microservice"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_MEDIUM"
  validation {
    condition = contains([
      "BUILD_GENERAL1_SMALL",
      "BUILD_GENERAL1_MEDIUM",
      "BUILD_GENERAL1_LARGE",
      "BUILD_GENERAL1_2XLARGE"
    ], var.codebuild_compute_type)
    error_message = "Must be a valid CodeBuild compute type."
  }
}

variable "github_repo_url" {
  description = "GitHub repository URL for the microservice"
  type        = string
  default     = ""
}

variable "github_token_secret_name" {
  description = "AWS Secrets Manager secret name for GitHub token"
  type        = string
  default     = "github-token"
}

variable "cross_account_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  sensitive   = true
}

variable "monitoring_retention_days" {
  description = "CloudWatch logs retention in days"
  type        = number
  default     = 30
}

variable "enable_xray" {
  description = "Enable AWS X-Ray tracing"
  type        = bool
  default     = true
}

variable "prometheus_workspace_alias" {
  description = "Amazon Managed Service for Prometheus workspace alias"
  type        = string
  default     = "microservices-monitoring"
}
