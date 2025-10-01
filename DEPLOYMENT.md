# Deployment Guide

This guide walks you through deploying the Multi-Account Microservices project with ECS, PrivateLink, Terraform, and AWS CDK.

## Prerequisites

Before starting, ensure you have the following installed and configured:

### Required Tools
- **Terraform 1.13+** - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- **Node.js 22+** - [Download](https://nodejs.org/)
- **AWS CLI** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **AWS CDK CLI** - Run: `npm install -g aws-cdk`

### AWS Configuration
1. Configure AWS CLI with appropriate credentials:
   ```bash
   aws configure
   ```

2. Set up AWS profiles for different accounts (if using multiple accounts):
   ```bash
   aws configure --profile networking-account
   aws configure --profile microservices-account-1
   aws configure --profile microservices-account-2
   ```

3. Bootstrap CDK in your AWS accounts:
   ```bash
   cdk bootstrap aws://ACCOUNT-NUMBER/REGION
   ```

## Quick Start

### Option 1: Automated Deployment
Use the provided deployment script:

```bash
# Deploy everything
./deploy.sh

# Deploy only Terraform infrastructure
./deploy.sh terraform

# Deploy only CDK microservices
./deploy.sh cdk
```

### Option 2: Manual Deployment

#### Step 1: Deploy Base Networking (Terraform)

1. Navigate to the Terraform directory:
   ```bash
   cd terraform-base-infra
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the plan:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. Export the outputs for CDK:
   ```bash
   export VPC_ID=$(terraform output -raw vpc_id)
   export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
   export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
   ```

#### Step 2: Deploy Microservices (AWS CDK)

1. Navigate to the CDK directory:
   ```bash
   cd ../cdk-microservices
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy the microservices stack:
   ```bash
   cdk deploy -c vpcId=$VPC_ID \
              -c publicSubnetIds="$PUBLIC_SUBNETS" \
              -c privateSubnetIds="$PRIVATE_SUBNETS" \
              -c microserviceName="my-microservice" \
              -c microservicePort="80" \
              -c microserviceImage="nginx:alpine"
   ```

## Multi-Account Deployment

For a true multi-account setup:

### Networking Account
1. Deploy Terraform infrastructure in the networking account
2. Note the VPC ID and subnet IDs from Terraform outputs

### Microservices Accounts
For each microservices account:

1. Switch to the appropriate AWS profile:
   ```bash
   export AWS_PROFILE=microservices-account-1
   ```

2. Deploy the CDK stack with the networking account's VPC details:
   ```bash
   cdk deploy -c vpcId=<VPC_ID_FROM_NETWORKING_ACCOUNT> \
              -c publicSubnetIds="<PUBLIC_SUBNETS_JSON>" \
              -c privateSubnetIds="<PRIVATE_SUBNETS_JSON>"
   ```

3. Note the VPC Endpoint Service IDs from the CDK outputs

4. Update other microservices' consumer endpoint configurations with the new service IDs

## Configuration

### Environment Variables
You can set these environment variables instead of using CDK context:

- `VPC_ID` - VPC ID from Terraform outputs
- `PUBLIC_SUBNETS` - JSON array of public subnet IDs
- `PRIVATE_SUBNETS` - JSON array of private subnet IDs
- `CDK_DEFAULT_ACCOUNT` - AWS account ID
- `CDK_DEFAULT_REGION` - AWS region

### CDK Context Variables
- `vpcId` - VPC ID to use
- `publicSubnetIds` - JSON array of public subnet IDs
- `privateSubnetIds` - JSON array of private subnet IDs
- `microserviceName` - Name of the microservice
- `microservicePort` - Port the microservice runs on
- `microserviceImage` - Docker image for the microservice
- `consumerEndpointServices` - Array of endpoint services to consume

### Example Configuration
```bash
cdk deploy \
  -c vpcId=vpc-12345678 \
  -c publicSubnetIds='["subnet-12345678","subnet-87654321"]' \
  -c privateSubnetIds='["subnet-11111111","subnet-22222222"]' \
  -c microserviceName="user-service" \
  -c microservicePort="80" \
  -c microserviceImage="my-registry/user-service:v1.0.0" \
  -c consumerEndpointServices='[{"serviceName":"notification-service","vpcEndpointServiceId":"com.amazonaws.vpce.us-east-1.vpce-svc-12345678","port":8081}]'
```

## Verification

After deployment, verify your setup:

1. **Check ECS Services**:
   ```bash
   aws ecs list-services --cluster <cluster-name>
   ```

2. **Check VPC Endpoint Services**:
   ```bash
   aws ec2 describe-vpc-endpoint-services --service-names <service-name>
   ```

3. **Check Network Load Balancers**:
   ```bash
   aws elbv2 describe-load-balancers
   ```

4. **Test Connectivity**:
   - Deploy a test container in the same VPC
   - Use the VPC endpoint service DNS name to test connectivity

## Troubleshooting

### Common Issues

1. **CDK Bootstrap Required**:
   ```bash
   cdk bootstrap aws://ACCOUNT-NUMBER/REGION
   ```

2. **VPC Not Found**:
   - Ensure the VPC ID is correct
   - Check that you're in the right AWS region
   - Verify the VPC exists in the target account

3. **Subnet Issues**:
   - Ensure subnets exist in the target VPC
   - Check that subnets are in the correct availability zones

4. **Permission Issues**:
   - Verify IAM permissions for ECS, VPC, and ELB services
   - Check cross-account resource policies for VPC endpoints

### Useful Commands

```bash
# List all CDK stacks
cdk list

# View CDK diff
cdk diff

# Destroy CDK stack
cdk destroy

# View Terraform state
terraform show

# Destroy Terraform infrastructure
terraform destroy
```

## Cleanup

To remove all resources:

1. **Destroy CDK Stack**:
   ```bash
   cd cdk-microservices
   cdk destroy
   ```

2. **Destroy Terraform Infrastructure**:
   ```bash
   cd terraform-base-infra
   terraform destroy
   ```

## Security Considerations

- Use least privilege IAM policies
- Enable VPC Flow Logs for monitoring
- Use AWS Secrets Manager for sensitive configuration
- Regularly rotate access keys and certificates
- Monitor VPC endpoint service usage
- Implement proper network ACLs and security groups

## Monitoring and Logging

- CloudWatch Logs are automatically configured for ECS services
- Enable VPC Flow Logs for network monitoring
- Set up CloudWatch alarms for service health
- Use AWS X-Ray for distributed tracing (optional)


