# Cross-Account Shared Services Configuration
# This file contains resources for cross-account CI/CD, monitoring, and shared services

# ECR repository policy for cross-account access
resource "aws_ecr_repository_policy" "microservice" {
  repository = aws_ecr_repository.microservice.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CrossAccountPull"
        Effect = "Allow"
        Principal = {
          AWS = flatten([
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root",
            [for account_id in local.organization_accounts.provider_account_ids : "arn:aws:iam::${account_id}:root"],
            [for account_id in local.organization_accounts.consumer_account_ids : "arn:aws:iam::${account_id}:root"]
          ])
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      },
      {
        Sid    = "CrossAccountPush"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# IAM role for cross-account monitoring access
resource "aws_iam_role" "monitoring_role" {
  name = "MonitoringRole-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = flatten([
            "arn:aws:iam::${local.organization_accounts.security_account_id}:root",
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root",
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
    Name        = "MonitoringRole-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account monitoring"
  }
}

# Monitoring policy
resource "aws_iam_role_policy" "monitoring_policy" {
  name = "MonitoringPolicy-${local.environment}"
  role = aws_iam_role.monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "aps:QueryMetrics",
          "aps:GetLabels",
          "aps:GetSeries",
          "aps:GetMetricMetadata",
          "aps:DescribeWorkspace",
          "aps:ListWorkspaces"
        ]
        Resource = [
          aws_prometheus_workspace.microservices.arn,
          "${aws_prometheus_workspace.microservices.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "xray:GetServiceGraph",
          "xray:GetTimeSeriesServiceStatistics",
          "xray:GetTraceSummaries",
          "xray:BatchGetTraces",
          "xray:GetTraceGraph"
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
          "arn:aws:logs:*:*:log-group:/ecs/application*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:GetDashboard",
          "cloudwatch:ListDashboards"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cross-account CI/CD role
resource "aws_iam_role" "cicd_role" {
  name = "CICDRole-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = flatten([
            "arn:aws:iam::${local.organization_accounts.networking_account_id}:root",
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
    Name        = "CICDRole-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account CI/CD"
  }
}

# CI/CD policy
resource "aws_iam_role_policy" "cicd_policy" {
  name = "CICDPolicy-${local.environment}"
  role = aws_iam_role.cicd_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          aws_ecr_repository.microservice.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}

# Parameter Store parameters for cross-account configuration
resource "aws_ssm_parameter" "ecr_repository_uri" {
  name  = "/shared-services/${local.environment}/ecr-repository-uri"
  type  = "String"
  value = aws_ecr_repository.microservice.repository_url

  tags = {
    Name        = "ECR-Repository-URI-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "prometheus_workspace_id" {
  name  = "/shared-services/${local.environment}/prometheus-workspace-id"
  type  = "String"
  value = aws_prometheus_workspace.microservices.id

  tags = {
    Name        = "Prometheus-Workspace-ID-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "monitoring_role_arn" {
  name  = "/shared-services/${local.environment}/monitoring-role-arn"
  type  = "String"
  value = aws_iam_role.monitoring_role.arn

  tags = {
    Name        = "Monitoring-Role-ARN-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "cicd_role_arn" {
  name  = "/shared-services/${local.environment}/cicd-role-arn"
  type  = "String"
  value = aws_iam_role.cicd_role.arn

  tags = {
    Name        = "CICD-Role-ARN-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

resource "aws_ssm_parameter" "artifacts_bucket_name" {
  name  = "/shared-services/${local.environment}/artifacts-bucket-name"
  type  = "String"
  value = aws_s3_bucket.artifacts.id

  tags = {
    Name        = "Artifacts-Bucket-Name-${local.environment}"
    Environment = local.environment
    Purpose     = "Cross-account configuration"
  }
}

