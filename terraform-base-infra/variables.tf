# Hardcoded configuration for independent deployment
locals {
  # Account configuration
  aws_region = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id
  
  # Network configuration
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  isolated_subnet_cidrs = ["10.0.5.0/28", "10.0.6.0/28"]
  
  # Multi-account configuration - empty for independent deployment
  microservices_accounts = []
  
  # Environment-specific configuration
  environment_config = {
    dev = {
      cross_account_external_id = "multi-account-dev-2024"
      log_retention_days = 7
      backup_retention_days = 7
    }
    staging = {
      cross_account_external_id = "multi-account-staging-2024"
      log_retention_days = 30
      backup_retention_days = 30
    }
    prod = {
      cross_account_external_id = "multi-account-prod-2024"
      log_retention_days = 90
      backup_retention_days = 90
    }
  }
  
  # Get current environment from workspace
  environment = terraform.workspace
  current_config = local.environment_config[local.environment]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
