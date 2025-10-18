# Hardcoded configuration for independent deployment
locals {
  # Account configuration
  aws_region = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id
  
  # Organization accounts - empty for independent deployment
  organization_accounts = {
    root_account_id         = ""
    security_account_id     = ""
    networking_account_id   = ""
    provider_account_ids    = []
    consumer_account_ids    = []
  }
  
  # Service configuration
  container_registry_name = "microservice"
  github_repo_url = "https://github.com/your-org/microservice"
  github_token_secret_name = "github-token"
  monitoring_retention_days = 30
  enable_xray = true
  prometheus_workspace_alias = "microservices-monitoring"
  
  # Environment-specific configuration
  environment_config = {
    dev = {
      cross_account_external_id = "multi-account-dev-2024"
      artifacts_s3_bucket_name = "microservice-artifacts-dev-2024"
    }
    staging = {
      cross_account_external_id = "multi-account-staging-2024"
      artifacts_s3_bucket_name = "microservice-artifacts-staging-2024"
    }
    prod = {
      cross_account_external_id = "multi-account-prod-2024"
      artifacts_s3_bucket_name = "microservice-artifacts-prod-2024"
    }
  }
  
  # Get current environment from workspace
  environment = terraform.workspace
  current_config = local.environment_config[local.environment]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
