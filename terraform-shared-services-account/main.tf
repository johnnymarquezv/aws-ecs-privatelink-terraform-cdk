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
            ["AWS/ECR", "RepositoryPullCount"],
            [".", "RepositoryPushCount"]
          ]
          period = 300
          stat   = "Sum"
          region = local.aws_region
          title  = "ECR Metrics"
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          query   = "SOURCE '/aws/monitoring/applications-${local.environment}' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = local.aws_region
          title   = "Recent Application Logs"
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

resource "aws_ssm_parameter" "github_repository" {
  name  = "/${local.environment}/shared-services/github-repository"
  type  = "String"
  value = "johnnymarquezv/aws-ecs-privatelink-terraform-cdk"

  tags = {
    Name        = "GitHub Repository Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "container_registry_url" {
  name  = "/${local.environment}/shared-services/container-registry-url"
  type  = "String"
  value = "ghcr.io/johnnymarquezv/aws-ecs-privatelink-terraform-cdk/microservice"

  tags = {
    Name        = "Container Registry URL Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}


# Secrets Manager secret for GitHub token
resource "aws_secretsmanager_secret" "github_token" {
  name                    = local.github_token_secret_name
  description             = "GitHub personal access token for CI/CD"
  recovery_window_in_days = 7

  tags = {
    Name        = "GitHub-Token-${local.environment}"
    Environment = local.environment
    Purpose     = "CI/CD Authentication"
  }
}

# Secrets Manager secret version (placeholder - actual token should be set manually)
resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string = jsonencode({
    token = "PLACEHOLDER_TOKEN_REPLACE_WITH_ACTUAL_GITHUB_TOKEN"
  })
}


