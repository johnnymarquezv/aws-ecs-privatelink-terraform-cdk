# Shared Services Account Main Configuration
# This account provides CI/CD, monitoring, and shared services for the organization

# Data source to get current AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for build artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifacts_s3_bucket_name

  tags = {
    Name        = "Build-Artifacts-${var.environment}"
    Environment = var.environment
    Purpose     = "CI/CD Artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECR repository for container images
resource "aws_ecr_repository" "microservice" {
  name                 = var.container_registry_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "Microservice-Registry-${var.environment}"
    Environment = var.environment
    Purpose     = "Container Registry"
  }
}

# ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "microservice" {
  repository = aws_ecr_repository.microservice.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "stage"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 3 development images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["dev", "development"]
          countType     = "imageCountMoreThan"
          countNumber   = 3
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}


# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "CodeBuildRole-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "CodeBuildRole-${var.environment}"
    Environment = var.environment
  }
}

# IAM policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildPolicy-${var.environment}"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.github_token.arn
      }
    ]
  })
}

# Secrets Manager secret for GitHub token
resource "aws_secretsmanager_secret" "github_token" {
  name        = var.github_token_secret_name
  description = "GitHub personal access token for CodeBuild"

  tags = {
    Name        = "GitHub-Token-${var.environment}"
    Environment = var.environment
    Purpose     = "CI/CD"
  }
}

# CodeBuild project for microservice
resource "aws_codebuild_project" "microservice" {
  name          = "microservice-build-${var.environment}"
  description   = "Build project for microservice"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.codebuild_compute_type
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.container_registry_name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name        = "Microservice-Build-${var.environment}"
    Environment = var.environment
    Purpose     = "CI/CD"
  }
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/microservice-build-${var.environment}"
  retention_in_days = var.monitoring_retention_days

  tags = {
    Name        = "CodeBuild-Logs-${var.environment}"
    Environment = var.environment
    Purpose     = "CI/CD Logging"
  }
}

# CloudWatch Log Group for application monitoring
resource "aws_cloudwatch_log_group" "application_monitoring" {
  name              = "/aws/monitoring/applications-${var.environment}"
  retention_in_days = var.monitoring_retention_days

  tags = {
    Name        = "Application-Monitoring-${var.environment}"
    Environment = var.environment
    Purpose     = "Application Monitoring"
  }
}

# X-Ray service map (if enabled)
resource "aws_xray_sampling_rule" "microservices" {
  count = var.enable_xray ? 1 : 0

  rule_name      = "microservices-sampling-${var.environment}"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = {
    Name        = "Microservices-Sampling-${var.environment}"
    Environment = var.environment
    Purpose     = "Distributed Tracing"
  }
}

# Amazon Managed Service for Prometheus workspace
resource "aws_prometheus_workspace" "microservices" {
  alias = var.prometheus_workspace_alias

  tags = {
    Name        = "Microservices-Prometheus-${var.environment}"
    Environment = var.environment
    Purpose     = "Metrics Collection"
  }
}


# SNS topic for deployment notifications
resource "aws_sns_topic" "deployment_notifications" {
  name = "deployment-notifications-${var.environment}"

  tags = {
    Name        = "Deployment-Notifications-${var.environment}"
    Environment = var.environment
    Purpose     = "CI/CD Notifications"
  }
}

# EventBridge rule for CodeBuild state changes
resource "aws_cloudwatch_event_rule" "codebuild_state_change" {
  name        = "codebuild-state-change-${var.environment}"
  description = "Capture CodeBuild state changes"

  event_pattern = jsonencode({
    source      = ["aws.codebuild"]
    detail-type = ["CodeBuild Build State Change"]
    detail = {
      build-status = ["SUCCEEDED", "FAILED", "STOPPED"]
    }
  })

  tags = {
    Name        = "CodeBuild-State-Change-${var.environment}"
    Environment = var.environment
  }
}

# EventBridge target for CodeBuild notifications
resource "aws_cloudwatch_event_target" "codebuild_notifications" {
  rule      = aws_cloudwatch_event_rule.codebuild_state_change.name
  target_id = "CodeBuildNotificationsTarget"
  arn       = aws_sns_topic.deployment_notifications.arn
}

# CloudWatch dashboard for shared services
resource "aws_cloudwatch_dashboard" "shared_services" {
  dashboard_name = "SharedServices-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/CodeBuild", "Builds", "ProjectName", aws_codebuild_project.microservice.name],
            [".", "Duration", ".", "."],
            [".", "SucceededBuilds", ".", "."],
            [".", "FailedBuilds", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "CodeBuild Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/codebuild/microservice-build-${var.environment}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Recent CodeBuild Logs"
        }
      }
    ]
  })
}

