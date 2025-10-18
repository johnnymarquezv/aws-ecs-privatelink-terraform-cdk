# Networking Account - Cross-Account Connectivity Infrastructure
# This account now focuses on providing connectivity between accounts rather than shared infrastructure

# Data sources
data "aws_availability_zones" "available" {}

# Transit Gateway for cross-account connectivity
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Transit Gateway for cross-account connectivity - ${local.environment}"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  
  tags = {
    Name        = "main-tgw-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Transit Gateway route table
resource "aws_ec2_transit_gateway_route_table" "main" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  
  tags = {
    Name        = "main-tgw-rt-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Cross-account IAM role for Transit Gateway sharing (only if microservices accounts are specified)
resource "aws_iam_role" "transit_gateway_sharing_role" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
  name = "TransitGatewaySharingRole-${local.environment}"
  
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
    Name        = "TransitGatewaySharingRole-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Policy for Transit Gateway sharing (only if role exists)
resource "aws_iam_role_policy" "transit_gateway_sharing_policy" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
  name = "TransitGatewaySharingPolicy-${local.environment}"
  role = aws_iam_role.transit_gateway_sharing_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTransitGateways",
          "ec2:DescribeTransitGatewayAttachments",
          "ec2:DescribeTransitGatewayRouteTables",
          "ec2:CreateTransitGatewayAttachment",
          "ec2:DeleteTransitGatewayAttachment",
          "ec2:ModifyTransitGatewayAttachment",
          "ec2:AcceptTransitGatewayAttachment",
          "ec2:RejectTransitGatewayAttachment",
          "ec2:CreateTransitGatewayRoute",
          "ec2:DeleteTransitGatewayRoute",
          "ec2:ReplaceTransitGatewayRoute",
          "ec2:SearchTransitGatewayRoutes"
        ]
        Resource = "*"
      }
    ]
  })
}

# RAM resource share for Transit Gateway
resource "aws_ram_resource_share" "transit_gateway_share" {
  name                      = "TransitGatewayShare-${local.environment}"
  allow_external_principals = false
  
  tags = {
    Name        = "TransitGateway-Share-${local.environment}"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# Associate Transit Gateway with resource share
resource "aws_ram_resource_association" "transit_gateway_association" {
  resource_arn       = aws_ec2_transit_gateway.main.arn
  resource_share_arn = aws_ram_resource_share.transit_gateway_share.arn
}

# Share Transit Gateway with microservices accounts (only if accounts are specified)
resource "aws_ram_principal_association" "microservices_accounts" {
  for_each = length(local.microservices_accounts) > 0 ? toset(local.microservices_accounts) : []
  
  principal          = each.value
  resource_share_arn = aws_ram_resource_share.transit_gateway_share.arn
}

# Cross-account role for general resource access (only if microservices accounts are specified)
resource "aws_iam_role" "cross_account_role" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
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

# Policy for cross-account resource access (only if role exists)
resource "aws_iam_role_policy" "cross_account_policy" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
  name = "CrossAccountPolicy-${local.environment}"
  role = aws_iam_role.cross_account_role[0].id
  
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
          "ec2:DescribeNatGateways",
          "ec2:DescribeTransitGateways",
          "ec2:DescribeTransitGatewayAttachments"
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
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${local.aws_region}:${local.account_id}:parameter/${local.environment}/connectivity/*"
        ]
      }
    ]
  })
}

# Centralized monitoring and logging infrastructure
resource "aws_cloudwatch_log_group" "cross_account_logs" {
  name              = "/cross-account/monitoring"
  retention_in_days = local.current_config.log_retention_days

  tags = {
    Name        = "cross-account-monitoring-logs"
    Environment = local.environment
    Project     = "Multi-Account-Microservices"
  }
}

# SSM Parameter Store for sharing connectivity information
resource "aws_ssm_parameter" "transit_gateway_id" {
  name  = "/${local.environment}/connectivity/transit-gateway-id"
  type  = "String"
  value = aws_ec2_transit_gateway.main.id

  tags = {
    Name        = "Transit Gateway ID Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}

resource "aws_ssm_parameter" "transit_gateway_route_table_id" {
  name  = "/${local.environment}/connectivity/transit-gateway-route-table-id"
  type  = "String"
  value = aws_ec2_transit_gateway_route_table.main.id

  tags = {
    Name        = "Transit Gateway Route Table ID Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}

resource "aws_ssm_parameter" "cross_account_role_arn" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
  name  = "/${local.environment}/connectivity/cross-account-role-arn"
  type  = "String"
  value = aws_iam_role.cross_account_role[0].arn

  tags = {
    Name        = "Cross Account Role ARN Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}

# Environment information
resource "aws_ssm_parameter" "environment" {
  name  = "/${local.environment}/connectivity/environment"
  type  = "String"
  value = local.environment

  tags = {
    Name        = "Environment Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}

resource "aws_ssm_parameter" "networking_account_id" {
  name  = "/${local.environment}/connectivity/networking-account-id"
  type  = "String"
  value = local.account_id

  tags = {
    Name        = "Networking Account ID Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}

resource "aws_ssm_parameter" "microservices_accounts" {
  count = length(local.microservices_accounts) > 0 ? 1 : 0
  name  = "/${local.environment}/connectivity/microservices-accounts"
  type  = "StringList"
  value = join(",", local.microservices_accounts)

  tags = {
    Name        = "Microservices Accounts Parameter"
    Environment = local.environment
    Purpose     = "Cross-Account Connectivity"
  }
}