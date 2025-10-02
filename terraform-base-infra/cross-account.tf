# Cross-Account Resource Sharing Configuration
# This file contains resources for sharing infrastructure across accounts

# Cross-account role for resource sharing
resource "aws_iam_role" "cross_account_role" {
  name = "CrossAccountRole-${var.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.microservices_accounts : "arn:aws:iam::${account_id}:root"
          ]
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.cross_account_external_id
          }
        }
      }
    ]
  })
  
  tags = {
    Name        = "CrossAccountRole-${var.environment}"
    Environment = var.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Policy for cross-account resource access
resource "aws_iam_role_policy" "cross_account_policy" {
  name = "CrossAccountPolicy-${var.environment}"
  role = aws_iam_role.cross_account_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVpcEndpointServices",
          "ec2:DescribeRouteTables",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNatGateways"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRoles"
        ]
        Resource = "*"
      }
    ]
  })
}

# Cross-account resource policy for VPC sharing
resource "aws_ram_resource_share" "vpc_share" {
  name                      = "VPC-Share-${var.environment}"
  description               = "Share VPC resources with microservices accounts"
  allow_external_principals = false
  
  tags = {
    Name        = "VPC-Share-${var.environment}"
    Environment = var.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Associate VPC with resource share
resource "aws_ram_resource_association" "vpc_association" {
  resource_arn       = aws_vpc.base.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate subnets with resource share
resource "aws_ram_resource_association" "subnet_associations" {
  for_each = toset(concat(aws_subnet.public[*].arn, aws_subnet.private[*].arn))
  
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate security groups with resource share
resource "aws_ram_resource_association" "security_group_associations" {
  for_each = toset([
    aws_security_group.base_default.arn,
    aws_security_group.base_private.arn,
    aws_security_group.vpc_endpoints.arn
  ])
  
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate VPC endpoints with resource share
resource "aws_ram_resource_association" "vpc_endpoint_associations" {
  for_each = toset([
    aws_vpc_endpoint.s3.arn,
    aws_vpc_endpoint.dynamodb.arn,
    aws_vpc_endpoint.ecr_dkr.arn,
    aws_vpc_endpoint.ecr_api.arn,
    aws_vpc_endpoint.cloudwatch_logs.arn
  ])
  
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate log groups with resource share
resource "aws_ram_resource_association" "log_group_associations" {
  for_each = toset([
    aws_cloudwatch_log_group.ecs_application_logs.arn,
    aws_cloudwatch_log_group.vpc_flow_logs.arn
  ])
  
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate IAM roles with resource share
resource "aws_ram_resource_association" "iam_role_associations" {
  for_each = toset([
    aws_iam_role.ecs_task_execution_role.arn,
    aws_iam_role.ecs_task_role.arn
  ])
  
  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Share resources with microservices accounts
resource "aws_ram_principal_association" "microservices_accounts" {
  for_each = toset(var.microservices_accounts)
  
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Cross-account VPC endpoint service policy
resource "aws_vpc_endpoint_service_policy" "cross_account_policy" {
  vpc_endpoint_service_id = aws_vpc_endpoint_service.microservice.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in var.microservices_accounts : "arn:aws:iam::${account_id}:root"
          ]
        }
        Action = [
          "vpc:CreateVpcEndpoint",
          "vpc:DescribeVpcEndpoints",
          "vpc:DescribeVpcEndpointServices"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC endpoint service for microservices
resource "aws_vpc_endpoint_service" "microservice" {
  vpc_endpoint_service_load_balancers = [aws_lb.microservice.arn]
  acceptance_required                 = false
  
  allowed_principals = [
    for account_id in var.microservices_accounts : "arn:aws:iam::${account_id}:root"
  ]
  
  tags = {
    Name        = "Microservice-VPC-Endpoint-Service-${var.environment}"
    Environment = var.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Load balancer for VPC endpoint service
resource "aws_lb" "microservice" {
  name               = "microservice-lb-${var.environment}"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.private[*].id
  
  tags = {
    Name        = "Microservice-LB-${var.environment}"
    Environment = var.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Target group for load balancer
resource "aws_lb_target_group" "microservice" {
  name     = "microservice-tg-${var.environment}"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.base.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name        = "Microservice-TG-${var.environment}"
    Environment = var.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Listener for load balancer
resource "aws_lb_listener" "microservice" {
  load_balancer_arn = aws_lb.microservice.arn
  port              = "80"
  protocol          = "TCP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservice.arn
  }
}
