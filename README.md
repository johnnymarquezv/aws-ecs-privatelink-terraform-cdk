# Multi-Account Microservices with AWS ECS, PrivateLink, Terraform, and CDK

A secure, scalable multi-account microservices architecture using AWS ECS, PrivateLink, Terraform, and AWS CDK (TypeScript).

## Architecture

**Terraform (Base Infrastructure)**
- **Base Infrastructure Account**: Transit Gateway, cross-account IAM roles, centralized monitoring
- **Security Account**: CloudTrail, Config, S3 buckets, cross-account policies
- **Shared Services**: ECR repository, S3 artifacts bucket, monitoring roles

**CDK (Application Infrastructure)**
- **Provider Accounts**: VPC, ECS clusters, Network Load Balancers, VPC Endpoint Services, databases (RDS PostgreSQL, DynamoDB, ElastiCache Redis)
- **Consumer Accounts**: VPC, ECS clusters, Interface VPC endpoints, Transit Gateway attachments

## Project Structure

```
├── terraform-base-infra/          # Core VPC and networking infrastructure
├── terraform-security-account/    # Security and compliance resources
├── terraform-shared-services-account/ # Shared services and CI/CD
├── cdk-provider-account/          # Service provider infrastructure
├── cdk-consumer-account/          # Service consumer infrastructure
└── microservice/                  # FastAPI microservice application
```

## Prerequisites

- AWS CLI configured
- Terraform >= 1.0
- Node.js >= 18
- Python >= 3.9
- Docker

## Quick Start

### 1. Deploy Base Infrastructure

```bash
cd terraform-base-infra
terraform init
terraform plan
terraform apply
```

### 2. Deploy Security Account

```bash
cd terraform-security-account
terraform init
terraform plan
terraform apply
```

### 3. Deploy Shared Services

```bash
cd terraform-shared-services-account
terraform init
terraform plan
terraform apply
```

### 4. Deploy Provider Account

```bash
cd cdk-provider-account
npm install
npm run build
npx cdk list
npx cdk deploy api-service-dev-stack
npx cdk deploy api-service-staging-stack
npx cdk deploy api-service-prod-stack
```

### 5. Deploy Consumer Account

```bash
cd cdk-consumer-account
npm install
npm run build
npx cdk list
npx cdk deploy api-consumer-dev-consumer-stack
npx cdk deploy api-consumer-staging-consumer-stack
npx cdk deploy api-consumer-prod-consumer-stack
```

## Configuration

All variables are hardcoded in the configuration files:

- **CDK Accounts**: Variables defined in `lib/config.ts`
- **Terraform**: Variables hardcoded in `main.tf` and `variables.tf` files
- **Account IDs**: Hardcoded in configuration files
- **AWS Profiles**: Hardcoded in CDK configuration files

## Microservice Development

### Local Development

```bash
cd microservice
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
python app/main.py
```

### Database Configuration

The microservice uses:
- **PostgreSQL (RDS Aurora)**: Primary database
- **DynamoDB**: Session management
- **Redis (ElastiCache)**: Caching

## Monitoring

- **CloudWatch**: Application logs and metrics
- **X-Ray**: Distributed tracing
- **CloudTrail**: API call logging
- **Config**: Resource compliance monitoring


## Security Features

- **Network Isolation**: Private subnets with NAT gateways
- **Encryption**: All data encrypted at rest and in transit
- **IAM Roles**: Least privilege access
- **VPC Endpoints**: Private connectivity to AWS services
- **Security Groups**: Restrictive network access rules

## Cost Optimization

- **Spot Instances**: For non-critical workloads
- **Reserved Instances**: For predictable workloads
- **Auto Scaling**: Based on CPU and memory utilization
- **Lifecycle Policies**: Automated cleanup of old resources

## Security Pipeline

1. **Infrastructure Security Scanning**
2. **Dependency Vulnerability Scanning**
3. **Container Image Security Scanning**
4. **Network Security Validation**
5. **Access Control Verification**
6. **Data Encryption Validation**
7. **Secrets Management Review**

