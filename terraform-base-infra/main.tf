resource "aws_vpc" "base" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "base-vpc-${local.environment}"
    Environment = local.environment
  }
}

resource "aws_subnet" "public" {
  count             = length(local.public_subnet_cidrs)
  cidr_block        = local.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  vpc_id            = aws_vpc.base.id
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(local.private_subnet_cidrs)
  cidr_block        = local.private_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.base.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "isolated" {
  count             = length(local.isolated_subnet_cidrs)
  cidr_block        = local.isolated_subnet_cidrs[count.index]
  vpc_id            = aws_vpc.base.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "isolated-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "vpc-gateway"
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  count  = length(aws_subnet.public)
  domain = "vpc"
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.base.id
  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "nat_gateway_route" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index % length(aws_nat_gateway.nat)].id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

data "aws_availability_zones" "available" {}

# Base Security Groups for centralized governance
resource "aws_security_group" "base_default" {
  name_prefix = "base-default-"
  vpc_id      = aws_vpc.base.id
  description = "Base security group with default deny-all rules"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "base-default-sg"
  }
}

resource "aws_security_group" "base_private" {
  name_prefix = "base-private-"
  vpc_id      = aws_vpc.base.id
  description = "Base security group for private subnet resources"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all traffic within security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "base-private-sg"
  }
}

# Shared VPC Endpoints for common AWS services
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.base.id
  service_name      = "com.amazonaws.${local.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "s3-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.base.id
  service_name      = "com.amazonaws.${local.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "dynamodb-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.base.id
  service_name        = "com.amazonaws.${local.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-dkr-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.base.id
  service_name        = "com.amazonaws.${local.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "ecr-api-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.base.id
  service_name        = "com.amazonaws.${local.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "cloudwatch-logs-vpc-endpoint"
  }
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "vpc-endpoints-"
  vpc_id      = aws_vpc.base.id
  description = "Security group for VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.base.cidr_block]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

# Base IAM roles for ECS tasks
resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "ecs-task-execution-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "ecs-task-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-role"
  }
}

# Centralized CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "ecs_application_logs" {
  name              = "/ecs/application"
  retention_in_days = local.current_config.log_retention_days

  tags = {
    Name = "ecs-application-logs"
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/vpc/flowlogs"
  retention_in_days = local.current_config.log_retention_days

  tags = {
    Name = "vpc-flow-logs"
  }
}

# VPC Flow Logs
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.base.id

  tags = {
    Name = "vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs_role" {
  name_prefix = "vpc-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "vpc-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
  name_prefix = "vpc-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# SSM Parameter Store resources for CDK integration
resource "aws_ssm_parameter" "vpc_id" {
  name  = "/${local.environment}/base-infra/vpc-id"
  type  = "String"
  value = aws_vpc.base.id

  tags = {
    Name        = "VPC ID Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "/${local.environment}/base-infra/public-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.public[*].id)

  tags = {
    Name        = "Public Subnet IDs Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "/${local.environment}/base-infra/private-subnet-ids"
  type  = "StringList"
  value = join(",", aws_subnet.private[*].id)

  tags = {
    Name        = "Private Subnet IDs Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "base_default_security_group_id" {
  name  = "/${local.environment}/base-infra/base-default-security-group-id"
  type  = "String"
  value = aws_security_group.base_default.id

  tags = {
    Name        = "Base Default Security Group ID Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "base_private_security_group_id" {
  name  = "/${local.environment}/base-infra/base-private-security-group-id"
  type  = "String"
  value = aws_security_group.base_private.id

  tags = {
    Name        = "Base Private Security Group ID Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "ecs_task_execution_role_arn" {
  name  = "/${local.environment}/base-infra/ecs-task-execution-role-arn"
  type  = "String"
  value = aws_iam_role.ecs_task_execution_role.arn

  tags = {
    Name        = "ECS Task Execution Role ARN Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "ecs_task_role_arn" {
  name  = "/${local.environment}/base-infra/ecs-task-role-arn"
  type  = "String"
  value = aws_iam_role.ecs_task_role.arn

  tags = {
    Name        = "ECS Task Role ARN Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}

resource "aws_ssm_parameter" "ecs_application_log_group_name" {
  name  = "/${local.environment}/base-infra/ecs-application-log-group-name"
  type  = "String"
  value = aws_cloudwatch_log_group.ecs_application_logs.name

  tags = {
    Name        = "ECS Application Log Group Name Parameter"
    Environment = local.environment
    Purpose     = "CDK Integration"
  }
}
