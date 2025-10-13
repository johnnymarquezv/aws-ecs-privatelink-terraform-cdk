# Hardcoded configuration constants
locals {
  # Account configuration
  aws_region = "us-east-1"
  account_id = "888888888888"  # Security Account ID
  
  # Organization accounts
  organization_accounts = {
    root_account_id         = "000000000000"
    networking_account_id   = "111111111111"
    shared_services_account_id = "999999999999"
    provider_account_ids    = ["222222222222"]
    consumer_account_ids    = ["333333333333"]
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
