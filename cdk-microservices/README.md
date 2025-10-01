# CDK Microservices Stack

This CDK project deploys ECS microservices with VPC Endpoint Services and VPC Endpoints for private, cross-account communication using AWS PrivateLink.

## Overview

This stack creates:
- **ECS Fargate Cluster** with containerized microservices
- **Network Load Balancers (NLBs)** for service exposure
- **VPC Endpoint Services** to expose microservices via PrivateLink (provider)
- **Interface VPC Endpoints** to consume other microservices (consumer)
- **Security Groups** with proper ingress/egress rules
- **CloudWatch Logs** for monitoring and debugging

## Microservice Configuration

**For this example**, the CDK deploys a publicly available microservice (nginx) that is suitable for testing:
- VPC Endpoint Service connectivity
- VPC Endpoint connectivity
- Health check endpoints
- Cross-account PrivateLink communication

The nginx microservice provides:
- Health check endpoint at `/health`
- Basic HTTP responses for connectivity testing
- Lightweight and reliable for infrastructure testing

## Prerequisites

- AWS CDK CLI installed (`npm install -g aws-cdk`)
- Node.js 22+ and npm
- AWS CLI configured
- Terraform base infrastructure deployed (VPC, subnets)

## Deployment

### Quick Start
```bash
# Install dependencies
npm install

# Deploy with context from Terraform outputs
cdk deploy -c vpcId=$VPC_ID \
           -c publicSubnetIds="$PUBLIC_SUBNETS" \
           -c privateSubnetIds="$PRIVATE_SUBNETS"
```

### Context Variables
- `vpcId` - VPC ID from Terraform outputs
- `publicSubnetIds` - JSON array of public subnet IDs
- `privateSubnetIds` - JSON array of private subnet IDs
- `microserviceName` - Name of the microservice (default: "microservice")
- `microservicePort` - Port the microservice runs on (default: 80 for nginx)
- `microserviceImage` - Docker image (default: "nginx:alpine")

## Testing VPC Endpoint Connectivity

After deployment, you can test connectivity:

1. **Get VPC Endpoint Service DNS name**:
   ```bash
   aws ec2 describe-vpc-endpoint-services --service-names <service-name>
   ```

2. **Test from within the VPC**:
   ```bash
   # Test nginx default page
   curl http://<vpc-endpoint-dns-name>/
   
   # Test nginx status (if available)
   curl http://<vpc-endpoint-dns-name>/nginx_status
   ```

3. **Test from local microservice** (see `../microservice/README.md` for local deployment)

## Useful Commands

* `npm run build`   compile typescript to js
* `npm run watch`   watch for changes and compile
* `npm run test`    perform the jest unit tests
* `npx cdk deploy`  deploy this stack to your default AWS account/region
* `npx cdk diff`    compare deployed stack with current state
* `npx cdk synth`   emits the synthesized CloudFormation template
* `npx cdk destroy` destroy the stack

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   ECS Service   │────│   NLB (Private)  │────│ VPC Endpoint    │
│   (nginx)       │    │                  │    │ Service         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                                                         │ PrivateLink
                                                         ▼
                                               ┌─────────────────┐
                                               │ VPC Endpoint    │
                                               │ (Consumer)      │
                                               └─────────────────┘
```

## Outputs

The stack provides these outputs:
- `VpcEndpointServiceId` - VPC Endpoint Service ID for cross-account sharing
- `VpcEndpointServiceName` - VPC Endpoint Service Name
- `NetworkLoadBalancerArn` - NLB ARN for monitoring
- `EcsClusterArn` - ECS Cluster ARN for management
