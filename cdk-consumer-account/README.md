# CDK Consumer Account

This CDK project deploys ECS microservices that **consume services** from other accounts via Interface VPC Endpoints and AWS PrivateLink.

## Quick Start

1. Install dependencies:
   ```bash
   npm install
   ```

2. Deploy using the deployment script:
   ```bash
   ./scripts/deploy-consumer-account.sh dev us-east-1 444444444444 api-consumer 80 nginx:alpine
   ```

## What This Deploys

- **ECS Fargate Cluster** with containerized microservices
- **Interface VPC Endpoints** to consume services from other accounts
- **Security Groups** with proper ingress/egress rules
- **CloudWatch Logs** for monitoring and debugging
- **Service discovery configuration** for cross-account services

## Configuration

See the main [README.md](../README.md) for comprehensive configuration details and deployment options.

## Outputs

- `ConsumerEndpointsCount` - Number of consumer VPC endpoints created
- `ConsumerClusterArn` - Consumer ECS Cluster ARN
- Individual endpoint DNS names for each consumed service

## License

MIT License