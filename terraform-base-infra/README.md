# Terraform Base Infrastructure

This Terraform configuration creates the foundational networking infrastructure and governance resources for the multi-account microservices architecture.

## Quick Start

1. Deploy using the deployment script:
   ```bash
   ./scripts/deploy-terraform-account.sh dev us-east-1 111111111111 222222222222,333333333333,444444444444
   ```

## What This Deploys

- **Core VPC Infrastructure**: VPC, subnets, gateways, routing tables
- **Base Security Groups**: Centralized security policies and governance
- **Shared VPC Endpoints**: Common AWS services (S3, DynamoDB, ECR, CloudWatch)
- **Base IAM Roles**: Security compliance and access management
- **Centralized Logging**: CloudWatch log groups with consistent retention policies
- **Network Monitoring**: VPC Flow Logs for security analysis

## Configuration

See the main [README.md](../README.md) for comprehensive configuration details and deployment options.

## Outputs

- `vpc_id` - VPC ID for CDK stacks
- `public_subnet_ids` - Public subnet IDs
- `private_subnet_ids` - Private subnet IDs
- `base_default_security_group_id` - Base default security group ID
- `base_private_security_group_id` - Base private security group ID
- `ecs_task_execution_role_arn` - ECS task execution role ARN
- `ecs_task_role_arn` - ECS task role ARN
- `ecs_application_log_group_name` - CloudWatch log group name

## License

MIT License
