# Shared Services Account Main Configuration
# This account provides CI/CD, monitoring, and shared services for the organization

# Data source to get current AWS account info
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket for build artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = local.current_config.artifacts_s3_bucket_name

  tags = {
    Name        = "Build-Artifacts-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD Artifacts"
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
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
  name                 = local.container_registry_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "Microservice-Registry-${local.environment}"
    Environment = local.environment
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
  name = "CodeBuildRole-${local.environment}"

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
    Name        = "CodeBuildRole-${local.environment}"
    Environment = local.environment
  }
}

# IAM policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "CodeBuildPolicy-${local.environment}"
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
  name        = local.github_token_secret_name
  description = "GitHub personal access token for CodeBuild"

  tags = {
    Name        = "GitHub-Token-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD"
  }
}

# CodeBuild project for microservice
resource "aws_codebuild_project" "microservice" {
  name          = "microservice-build-${local.environment}"
  description   = "Build project for microservice"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = local.codebuild_compute_type
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = local.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = local.container_registry_name
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = local.environment
    }
  }

  source {
    type = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  tags = {
    Name        = "Microservice-Build-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD"
  }
}

# CloudWatch Log Group for CodeBuild
resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/microservice-build-${local.environment}"
  retention_in_days = local.monitoring_retention_days

  tags = {
    Name        = "CodeBuild-Logs-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD Logging"
  }
}

# CloudWatch Log Group for application monitoring
resource "aws_cloudwatch_log_group" "application_monitoring" {
  name              = "/aws/monitoring/applications-${local.environment}"
  retention_in_days = local.monitoring_retention_days

  tags = {
    Name        = "Application-Monitoring-${local.environment}"
    Environment = local.environment
    Purpose     = "Application Monitoring"
  }
}

# X-Ray service map (if enabled)
resource "aws_xray_sampling_rule" "microservices" {
  count = local.enable_xray ? 1 : 0

  rule_name      = "microservices-sampling-${local.environment}"
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
    Name        = "Microservices-Sampling-${local.environment}"
    Environment = local.environment
    Purpose     = "Distributed Tracing"
  }
}

# Amazon Managed Service for Prometheus workspace
resource "aws_prometheus_workspace" "microservices" {
  alias = local.prometheus_workspace_alias

  tags = {
    Name        = "Microservices-Prometheus-${local.environment}"
    Environment = local.environment
    Purpose     = "Metrics Collection"
  }
}


# SNS topic for deployment notifications
resource "aws_sns_topic" "deployment_notifications" {
  name = "deployment-notifications-${local.environment}"

  tags = {
    Name        = "Deployment-Notifications-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD Notifications"
  }
}

# EventBridge rule for CodeBuild state changes
resource "aws_cloudwatch_event_rule" "codebuild_state_change" {
  name        = "codebuild-state-change-${local.environment}"
  description = "Capture CodeBuild state changes"

  event_pattern = jsonencode({
    source      = ["aws.codebuild"]
    detail-type = ["CodeBuild Build State Change"]
    detail = {
      build-status = ["SUCCEEDED", "FAILED", "STOPPED"]
    }
  })

  tags = {
    Name        = "CodeBuild-State-Change-${local.environment}"
    Environment = local.environment
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
  dashboard_name = "SharedServices-${local.environment}"

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
          region = local.aws_region
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
          query   = "SOURCE '/aws/codebuild/microservice-build-${local.environment}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = local.aws_region
          title   = "Recent CodeBuild Logs"
        }
      }
    ]
  })
}

# SSM Parameter Store resources for CDK integration
resource "aws_ssm_parameter" "artifacts_s3_bucket" {
  name  = "/${local.environment}/shared-services/artifacts-s3-bucket"
  type  = "String"
  value = aws_s3_bucket.artifacts.bucket

  tags = {
    Name        = "Artifacts S3 Bucket Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "/${local.environment}/shared-services/ecr-repository-url"
  type  = "String"
  value = aws_ecr_repository.microservice.repository_url

  tags = {
    Name        = "ECR Repository URL Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}


