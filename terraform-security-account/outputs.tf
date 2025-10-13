# Security Account Outputs

# CloudTrail
output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = aws_cloudtrail.organization_trail.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail_logs.bucket
}

# AWS Config
output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = aws_config_configuration_recorder.main.name
}

output "config_s3_bucket" {
  description = "S3 bucket for AWS Config"
  value       = aws_s3_bucket.config_logs.bucket
}

# GuardDuty
output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

# Security Hub
output "security_hub_arn" {
  description = "Security Hub ARN"
  value       = aws_securityhub_account.main.arn
}

# Inspector
output "inspector_enabler_id" {
  description = "Inspector V2 enabler ID"
  value       = aws_inspector2_enabler.main.id
}

# Cross-account roles
output "security_audit_role_arn" {
  description = "ARN of the security audit role for cross-account access"
  value       = aws_iam_role.security_audit_role.arn
}

output "cloudtrail_access_role_arn" {
  description = "ARN of the CloudTrail access role for cross-account access"
  value       = aws_iam_role.cloudtrail_access_role.arn
}

# SNS topic
output "security_alerts_topic_arn" {
  description = "ARN of the security alerts SNS topic"
  value       = aws_sns_topic.security_alerts.arn
}

# CloudWatch Log Groups
output "security_events_log_group" {
  description = "CloudWatch log group for security events"
  value       = aws_cloudwatch_log_group.security_events.name
}

output "guardduty_findings_log_group" {
  description = "CloudWatch log group for GuardDuty findings"
  value       = aws_cloudwatch_log_group.guardduty_findings.name
}

# Account information
output "account_id" {
  description = "Security account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "environment" {
  description = "Environment name"
  value       = local.environment
}
