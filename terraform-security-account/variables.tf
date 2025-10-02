variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "Current AWS account ID (Security Account)"
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
    networking_account_id   = string
    shared_services_account_id = string
    provider_account_ids    = list(string)
    consumer_account_ids    = list(string)
  })
}

variable "cloudtrail_s3_bucket_name" {
  description = "S3 bucket name for CloudTrail logs"
  type        = string
}

variable "config_s3_bucket_name" {
  description = "S3 bucket name for AWS Config"
  type        = string
}

variable "security_hub_standards" {
  description = "List of Security Hub standards to enable"
  type        = list(string)
  default = [
    "aws-foundational-security-standard",
    "cis-aws-foundations-benchmark",
    "pci-dss"
  ]
}

variable "guardduty_finding_publishing_frequency" {
  description = "GuardDuty finding publishing frequency"
  type        = string
  default     = "FIFTEEN_MINUTES"
  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.guardduty_finding_publishing_frequency)
    error_message = "Must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "inspector_assessment_duration" {
  description = "Inspector assessment duration in seconds"
  type        = number
  default     = 3600
}

variable "cross_account_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  sensitive   = true
}
