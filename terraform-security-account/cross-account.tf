# Cross-Account Security Configuration
# This file contains resources for cross-account security auditing and monitoring

# Cross-account role for security auditing
resource "aws_iam_role" "security_audit_role" {
  name = "SecurityAuditRole-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = flatten([
            "arn:aws:iam::${local.organization_accounts.root_account_id}:root",
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root",
            "arn:aws:iam::${local.organization_accounts.shared_services_account_id}:root",
            [for account_id in local.organization_accounts.provider_account_ids : "arn:aws:iam::${account_id}:root"],
            [for account_id in local.organization_accounts.consumer_account_ids : "arn:aws:iam::${account_id}:root"]
          ])
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.current_config.cross_account_external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "SecurityAuditRole-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account security auditing"
  }
}

# Security audit policy
resource "aws_iam_role_policy" "security_audit_policy" {
  name = "SecurityAuditPolicy-${local.environment}"
  role = aws_iam_role.security_audit_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "guardduty:GetDetector",
          "guardduty:GetFindings",
          "guardduty:ListDetectors",
          "guardduty:ListFindings",
          "securityhub:GetFindings",
          "securityhub:GetInsights",
          "securityhub:DescribeHub",
          "config:GetComplianceDetailsByConfigRule",
          "config:GetComplianceDetailsByResource",
          "config:DescribeConfigRules",
          "config:DescribeComplianceByConfigRule",
          "inspector2:ListFindings",
          "inspector2:GetFindings",
          "inspector2:DescribeOrganizationConfiguration"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = [
          "arn:aws:logs:*:*:log-group:/aws/guardduty/*",
          "arn:aws:logs:*:*:log-group:/aws/securityhub/*",
          "arn:aws:logs:*:*:log-group:/aws/config/*"
        ]
      }
    ]
  })
}

# Cross-account CloudTrail access role
resource "aws_iam_role" "cloudtrail_access_role" {
  name = "CloudTrailAccessRole-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = flatten([
            "arn:aws:iam::${local.organization_accounts.root_account_id}:root",
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root",
            "arn:aws:iam::${local.organization_accounts.shared_services_account_id}:root"
          ])
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = local.current_config.cross_account_external_id
          }
        }
      }
    ]
  })

  tags = {
    Name        = "CloudTrailAccessRole-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account CloudTrail access"
  }
}

# CloudTrail access policy
resource "aws_iam_role_policy" "cloudtrail_access_policy" {
  name = "CloudTrailAccessPolicy-${local.environment}"
  role = aws_iam_role.cloudtrail_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:LookupEvents",
          "cloudtrail:GetTrailStatus",
          "cloudtrail:DescribeTrails"
        ]
        Resource = "*"
      }
    ]
  })
}

# Parameter Store parameters for cross-account configuration
resource "aws_ssm_parameter" "security_audit_role_arn" {
  name  = "/security/${local.environment}/security-audit-role-arn"
  type  = "String"
  value = aws_iam_role.security_audit_role.arn

  tags = {
    Name        = "Security-Audit-Role-ARN-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "cloudtrail_access_role_arn" {
  name  = "/security/${local.environment}/cloudtrail-access-role-arn"
  type  = "String"
  value = aws_iam_role.cloudtrail_access_role.arn

  tags = {
    Name        = "CloudTrail-Access-Role-ARN-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "cloudtrail_s3_bucket_arn" {
  name  = "/security/${local.environment}/cloudtrail-s3-bucket-arn"
  type  = "String"
  value = aws_s3_bucket.cloudtrail_logs.arn

  tags = {
    Name        = "CloudTrail-S3-Bucket-ARN-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "guardduty_detector_id" {
  name  = "/security/${local.environment}/guardduty-detector-id"
  type  = "String"
  value = aws_guardduty_detector.main.id

  tags = {
    Name        = "GuardDuty-Detector-ID-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}
