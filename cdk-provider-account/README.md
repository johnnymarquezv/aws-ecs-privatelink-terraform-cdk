# CDK Provider Account

This CDK project deploys ECS microservices that **provide services** to other accounts via VPC Endpoint Services and AWS PrivateLink.

## Quick Start

1. Install dependencies:
   ```bash
   npm install
   ```

2. Deploy using the deployment script:
   ```bash
   ./scripts/deploy-provider-account.sh dev us-east-1 222222222222 api-service 8080 nginx:alpine
   ```

## What This Deploys

- **ECS Fargate Cluster** with containerized microservices
- **Network Load Balancers (NLBs)** for service exposure
- **VPC Endpoint Services** to expose microservices via PrivateLink
- **Security Groups** with proper ingress/egress rules
- **CloudWatch Logs** for monitoring and debugging
- **Cross-account resource policies** for service sharing

## Configuration

See the main [README.md](../README.md) for comprehensive configuration details and deployment options.

## Outputs

- `VpcEndpointServiceId` - VPC Endpoint Service ID for cross-account sharing
- `VpcEndpointServiceDnsName` - DNS name for the VPC Endpoint Service
- `NetworkLoadBalancerDnsName` - DNS name for the Network Load Balancer
- `EcsClusterArn` - ECS Cluster ARN
- `EcsServiceArn` - ECS Service ARN

## License

MIT License