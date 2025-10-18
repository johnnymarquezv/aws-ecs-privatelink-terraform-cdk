# Hardcoded configuration for independent deployment
locals {
  # Account configuration
  aws_region = "us-east-1"
  account_id = data.aws_caller_identity.current.account_id
  
  # Organization accounts - empty for independent deployment
  organization_accounts = {
    root_account_id         = ""
    networking_account_id   = ""
    shared_services_account_id = ""
    provider_account_ids    = []
    consumer_account_ids    = []
  }
  
  # Security configuration
  security_hub_standards = [
    "aws-foundational-security-standard",
    "cis-aws-foundations-benchmark",
    "pci-dss"
  ]
  
  guardduty_finding_publishing_frequency = "FIFTEEN_MINUTES"
  inspector_assessment_duration = 3600
  
  # Environment-specific configuration
  environment_config = {
    dev = {
      cross_account_external_id = "multi-account-dev-2024"
      cloudtrail_s3_bucket_name = "cloudtrail-logs-dev-2024"
      config_s3_bucket_name = "config-logs-dev-2024"
    }
    staging = {
      cross_account_external_id = "multi-account-staging-2024"
      cloudtrail_s3_bucket_name = "cloudtrail-logs-staging-2024"
      config_s3_bucket_name = "config-logs-staging-2024"
    }
    prod = {
      cross_account_external_id = "multi-account-prod-2024"
      cloudtrail_s3_bucket_name = "cloudtrail-logs-prod-2024"
      config_s3_bucket_name = "config-logs-prod-2024"
    }
  }
  
  # Get current environment from workspace
  environment = terraform.workspace
  current_config = local.environment_config[local.environment]
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
