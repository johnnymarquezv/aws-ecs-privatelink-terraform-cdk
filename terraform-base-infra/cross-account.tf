# Cross-Account Resource Sharing Configuration
# This file contains resources for sharing infrastructure across accounts

# Cross-account role for resource sharing
resource "aws_iam_role" "cross_account_role" {
  name = "CrossAccountRole-${local.environment}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = [
            for account_id in local.microservices_accounts : "arn:aws:iam::${account_id}:root"
          ]
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
    Name        = "CrossAccountRole-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Policy for cross-account resource access
resource "aws_iam_role_policy" "cross_account_policy" {
  name = "CrossAccountPolicy-${local.environment}"
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
  name                      = "VPC-Share-${local.environment}"
  allow_external_principals = false
  
  tags = {
    Name        = "VPC-Share-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Associate VPC with resource share
resource "aws_ram_resource_association" "vpc_association" {
  resource_arn       = aws_vpc.base.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate public subnets with resource share
resource "aws_ram_resource_association" "public_subnet_1" {
  resource_arn       = aws_subnet.public[0].arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "public_subnet_2" {
  resource_arn       = aws_subnet.public[1].arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate private subnets with resource share
resource "aws_ram_resource_association" "private_subnet_1" {
  resource_arn       = aws_subnet.private[0].arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "private_subnet_2" {
  resource_arn       = aws_subnet.private[1].arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate security groups with resource share
resource "aws_ram_resource_association" "base_default_sg" {
  resource_arn       = aws_security_group.base_default.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "base_private_sg" {
  resource_arn       = aws_security_group.base_private.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "vpc_endpoints_sg" {
  resource_arn       = aws_security_group.vpc_endpoints.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate VPC endpoints with resource share
resource "aws_ram_resource_association" "s3_endpoint" {
  resource_arn       = aws_vpc_endpoint.s3.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "dynamodb_endpoint" {
  resource_arn       = aws_vpc_endpoint.dynamodb.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "ecr_dkr_endpoint" {
  resource_arn       = aws_vpc_endpoint.ecr_dkr.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "ecr_api_endpoint" {
  resource_arn       = aws_vpc_endpoint.ecr_api.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "cloudwatch_logs_endpoint" {
  resource_arn       = aws_vpc_endpoint.cloudwatch_logs.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate log groups with resource share
resource "aws_ram_resource_association" "ecs_application_logs" {
  resource_arn       = aws_cloudwatch_log_group.ecs_application_logs.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "vpc_flow_logs" {
  resource_arn       = aws_cloudwatch_log_group.vpc_flow_logs.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Associate IAM roles with resource share
resource "aws_ram_resource_association" "ecs_task_execution_role" {
  resource_arn       = aws_iam_role.ecs_task_execution_role.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

resource "aws_ram_resource_association" "ecs_task_role" {
  resource_arn       = aws_iam_role.ecs_task_role.arn
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}

# Share resources with microservices accounts
resource "aws_ram_principal_association" "microservices_accounts" {
  for_each = toset(local.microservices_accounts)
  
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.vpc_share.arn
}
