# Security Account Main Configuration
# This account provides centralized security services for the organization

# Data source to get current AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = local.current_config.cloudtrail_s3_bucket_name

  tags = {
    Name        = "CloudTrail-Logs-${local.environment}"
    Environment = local.environment
    Purpose     = "CloudTrail Logging"
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

# Organization-wide CloudTrail
resource "aws_cloudtrail" "organization_trail" {
  name           = "organization-trail-${local.environment}"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.bucket

  event_selector {
    read_write_type                 = "All"
    include_management_events       = true
    exclude_management_event_sources = []

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::*/*"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }

  tags = {
    Name        = "Organization-CloudTrail-${local.environment}"
    Environment = local.environment
    Purpose     = "Organization Audit Trail"
  }
}

# S3 bucket for AWS Config
resource "aws_s3_bucket" "config_logs" {
  bucket = local.current_config.config_s3_bucket_name

  tags = {
    Name        = "Config-Logs-${local.environment}"
    Environment = local.environment
    Purpose     = "AWS Config"
  }
}

resource "aws_s3_bucket_versioning" "config_logs" {
  bucket = aws_s3_bucket.config_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config_logs" {
  bucket = aws_s3_bucket.config_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config_logs" {
  bucket = aws_s3_bucket.config_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "AWSConfigRole-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "AWSConfigRole-${local.environment}"
    Environment = local.environment
  }
}

resource "aws_iam_role_policy_attachment" "config_role_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/ConfigRole"
}

# AWS Config Configuration Recorder
resource "aws_config_configuration_recorder" "main" {
  name     = "main-recorder-${local.environment}"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

# AWS Config Delivery Channel
resource "aws_config_delivery_channel" "main" {
  name           = "main-delivery-channel-${local.environment}"
  s3_bucket_name = aws_s3_bucket.config_logs.bucket
}

# GuardDuty
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = local.guardduty_finding_publishing_frequency

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name        = "GuardDuty-${local.environment}"
    Environment = local.environment
  }
}

# Security Hub
resource "aws_securityhub_account" "main" {
  enable_default_standards = true
}

# Enable Security Hub standards
resource "aws_securityhub_standards_subscription" "standards" {
  for_each      = toset(local.security_hub_standards)
  standards_arn = "arn:aws:securityhub:::ruleset/finding-format/${each.key}/v/1.2.0"
}

# Inspector V2
resource "aws_inspector2_enabler" "main" {
  account_ids    = [data.aws_caller_identity.current.account_id]
  resource_types = ["ECR", "EC2"]
}

# CloudWatch Log Group for security events
resource "aws_cloudwatch_log_group" "security_events" {
  name              = "/aws/security/events-${local.environment}"
  retention_in_days = 90

  tags = {
    Name        = "Security-Events-${local.environment}"
    Environment = local.environment
    Purpose     = "Security Event Logging"
  }
}

# CloudWatch Log Group for GuardDuty findings
resource "aws_cloudwatch_log_group" "guardduty_findings" {
  name              = "/aws/guardduty/findings-${local.environment}"
  retention_in_days = 90

  tags = {
    Name        = "GuardDuty-Findings-${local.environment}"
    Environment = local.environment
    Purpose     = "GuardDuty Findings"
  }
}

# EventBridge rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings-${local.environment}"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })

  tags = {
    Name        = "GuardDuty-Findings-Rule-${local.environment}"
    Environment = local.environment
  }
}

# EventBridge target for GuardDuty findings
resource "aws_cloudwatch_event_target" "guardduty_findings" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "GuardDutyFindingsTarget"
  arn       = aws_cloudwatch_log_group.guardduty_findings.arn
}

# EventBridge rule for Security Hub findings
resource "aws_cloudwatch_event_rule" "security_hub_findings" {
  name        = "security-hub-findings-${local.environment}"
  description = "Capture Security Hub findings"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
  })

  tags = {
    Name        = "Security-Hub-Findings-Rule-${local.environment}"
    Environment = local.environment
  }
}

# EventBridge target for Security Hub findings
resource "aws_cloudwatch_event_target" "security_hub_findings" {
  rule      = aws_cloudwatch_event_rule.security_hub_findings.name
  target_id = "SecurityHubFindingsTarget"
  arn       = aws_cloudwatch_log_group.security_events.arn
}


# SNS topic for security alerts
resource "aws_sns_topic" "security_alerts" {
  name = "security-alerts-${local.environment}"

  tags = {
    Name        = "Security-Alerts-${local.environment}"
    Environment = local.environment
    Purpose     = "Security alerting"
  }
}

# SNS topic policy
resource "aws_sns_topic_policy" "security_alerts" {
  arn = aws_sns_topic.security_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "cloudwatch.amazonaws.com"
          ]
        }
        Action = "sns:Publish"
        Resource = aws_sns_topic.security_alerts.arn
      }
    ]
  })
}

# CloudWatch alarm for high severity GuardDuty findings
resource "aws_cloudwatch_metric_alarm" "high_severity_findings" {
  alarm_name          = "high-severity-guardduty-findings-${local.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FindingCount"
  namespace           = "AWS/GuardDuty"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors high severity GuardDuty findings"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  dimensions = {
    DetectorId = aws_guardduty_detector.main.id
    Severity   = "High"
  }

  tags = {
    Name        = "High-Severity-GuardDuty-Findings-${local.environment}"
    Environment = local.environment
  }
}
