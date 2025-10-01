# Multi-Account Project with Bidirectional Intercommunicating Microservices Using ECS, PrivateLink, Terraform, and AWS CDK (TypeScript)

This project implements a secure, scalable multi-account AWS architecture enabling bidirectional intercommunication among ECS microservices. It combines Terraform for foundational networking and AWS CDK (TypeScript) for microservices infrastructure, ensuring clear separation and independence.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
    - [Multi-account roles](#multi-account-roles)
    - [Bidirectional microservices connectivity](#bidirectional-microservices-connectivity)
    - [Networking and private connectivity](#networking-and-private-connectivity)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Folder Roles in AWS CDK](#folder-roles-in-aws-cdk)
- [Deployment Workflow](#deployment-workflow)
    - [Step 1 – Networking (Terraform, Networking Account)](#step-1--networking-terraform-networking-account)
    - [Step 2 – Microservices (AWS CDK, Microservices Accounts)](#step-2--microservices-aws-cdk-microservices-accounts)
- [Development Process](#development-process)
- [Why Hybrid Terraform + AWS CDK?](#why-hybrid-terraform--aws-cdk)
- [Additional Resources](#additional-resources)
- [License](#license)

---

## Overview

- **Terraform** provisions **core VPC networking infrastructure** and **governance resources** in a centralized **Networking Account**:
    - VPC, subnets, IGWs, NAT gateways
    - Base security groups for centralized governance
    - Shared VPC endpoints (S3, DynamoDB, ECR, CloudWatch Logs)
    - Base IAM roles and policies for security compliance
    - Centralized CloudWatch log groups with retention policies
    - VPC Flow Logs for network monitoring

- **AWS CDK** provisions **microservices infrastructure** in separate **Microservices Accounts**:
    - ECS clusters, services, task definitions
    - Each microservice exposes its API by provisioning **Network Load Balancers (NLBs)**
    - CDK manages **VPC Endpoint Services** to expose these NLBs, acting as provider endpoints
    - **Separate Connectivity Stack** manages interface VPC endpoints to consume other microservices' VPC Endpoint Services
    - **For this example**: CDK deploys a publicly available microservice (nginx) suitable for testing VPC endpoint connectivity

This **enhanced split** maintains independence while improving security governance, operational consistency, and clear separation of concerns between foundational infrastructure and application-specific resources.

---

## Architecture

### Multi-account roles

- **Networking Account (Terraform):**
    - Owns the core VPC, subnets, routing, NAT gateways, and Internet Gateway
    - Manages base security groups for centralized governance
    - Provisions shared VPC endpoints for common AWS services (S3, DynamoDB, ECR, CloudWatch Logs)
    - Manages base IAM roles and policies for security compliance
    - Centralizes CloudWatch log groups with consistent retention policies
    - Enables VPC Flow Logs for network monitoring
    - Does **not** provision microservice exposure resources

- **Microservices Accounts (CDK):**
    - Own ECS microservices, their NLBs, and corresponding **VPC Endpoint Services** (provider part)
    - **Separate Connectivity Stack** manages interface VPC endpoints to consume other microservices' exposed services (consumer part)
    - Enable cross-account private connectivity using AWS PrivateLink
    - Focus on application-specific infrastructure and security rules

### Bidirectional microservices connectivity

- Microservices expose APIs through NLBs paired with VPC Endpoint Services (managed by CDK Microservices Stack)
- Microservices consume APIs through interface VPC endpoints (managed by CDK Connectivity Stack)
- Communication is private, secure, and fully managed by CDK stacks independent of Terraform base networking
- Clear separation between service provision (Microservices Stack) and service consumption (Connectivity Stack)

### Networking and private connectivity

- Terraform provisions the foundational network and governance resources without dependency on microservices infrastructure
- CDK imports VPC, subnet constructs, security groups, IAM roles, and log groups from Terraform outputs
- CDK manages application-specific infrastructure while leveraging centrally governed base resources
- Cross-account resource policies and IAM roles secure PrivateLink connections
- Enhanced security through centralized governance of base security groups and IAM policies

---

## Project Structure

```
aws-infra-project/
├── terraform-base-infra/          # Terraform for core VPC/networking + governance in Networking Account
│   ├── main.tf                   # VPC, subnets, security groups, VPC endpoints, IAM roles, logs
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── cdk-microservices/             # AWS CDK (TypeScript) managing microservices infrastructure
│   ├── bin/
│   │   └── app.ts                 # CDK app entry point (Microservices + Connectivity stacks)
│   ├── lib/
│   │   ├── microservices-stack.ts # ECS cluster, NLBs, VPC Endpoint Services (provider)
│   │   └── connectivity-stack.ts  # Interface VPC endpoints (consumer)
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
└── microservice/                  # Local microservice for testing VPC endpoint connectivity
    ├── Dockerfile
    ├── app/                       # FastAPI application with health endpoints
    └── README.md                  # Local deployment and testing instructions
```

---

## Prerequisites

- Terraform 1.13+ (recommend using [tfenv](https://github.com/tfutils/tfenv))
- Node.js 22+ and npm
- AWS CLI configured with appropriate profiles
- AWS CDK CLI installed globally (`npm install -g aws-cdk`)

---

## Folder Roles in AWS CDK

- **bin/**: CDK app entry point, bootstraps stacks by reading context and parameters.
- **lib/**: Stacks and constructs defining all microservices infrastructure including ECS clusters, NLBs, and bidirectional VPC Endpoint Services.

---

## Deployment Workflow

### Step 1 – Networking (Terraform, Networking Account)

Deploy core network resources:

```bash
cd terraform-base-infra
terraform init
terraform apply -auto-approve
```

Export key network and governance outputs for CDK stacks:

```bash
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
export BASE_DEFAULT_SECURITY_GROUP_ID=$(terraform output -raw base_default_security_group_id)
export BASE_PRIVATE_SECURITY_GROUP_ID=$(terraform output -raw base_private_security_group_id)
export ECS_TASK_EXECUTION_ROLE_ARN=$(terraform output -raw ecs_task_execution_role_arn)
export ECS_TASK_ROLE_ARN=$(terraform output -raw ecs_task_role_arn)
export ECS_APPLICATION_LOG_GROUP_NAME=$(terraform output -raw ecs_application_log_group_name)
```

### Step 2 – Microservices (AWS CDK, Microservices Accounts)

Deploy microservices stacks (provider) and connectivity stack (consumer):

```bash
cd ../cdk-microservices
npm install
cdk deploy -c vpcId=$VPC_ID \
           -c publicSubnetIds="$PUBLIC_SUBNETS" \
           -c privateSubnetIds="$PRIVATE_SUBNETS" \
           -c baseDefaultSecurityGroupId="$BASE_DEFAULT_SECURITY_GROUP_ID" \
           -c basePrivateSecurityGroupId="$BASE_PRIVATE_SECURITY_GROUP_ID" \
           -c ecsTaskExecutionRoleArn="$ECS_TASK_EXECUTION_ROLE_ARN" \
           -c ecsTaskRoleArn="$ECS_TASK_ROLE_ARN" \
           -c ecsApplicationLogGroupName="$ECS_APPLICATION_LOG_GROUP_NAME"
```

Repeat deployment per microservice AWS account accordingly.

---

## Development Process

- Terraform base networking is modified and deployed independently without coupling to CDK microservices stacks.
- AWS CDK manages full lifecycle of microservices NLBs and VPC Endpoint Services for bidirectional PrivateLink connectivity.
- Stable Terraform outputs form the contract between accounts; CDK imports these network resources for service deployments.
- **Local microservice** (in `microservice/` directory) can be deployed locally for testing VPC endpoint connectivity.
- **CDK-deployed microservice** uses a publicly available image (nginx) suitable for testing both VPC endpoint services and VPC endpoints.

---

## Why Hybrid Terraform + AWS CDK?

- **Terraform** provides consistent, stable base networking infrastructure and governance resources shared across all accounts
- **AWS CDK** offers rich, typed programming constructs to independently model microservices infrastructure with complex bidirectional connectivity needs
- **Enhanced separation** improves security governance by centralizing base security groups, IAM roles, and log management
- **Clear boundaries** simplify team responsibilities: networking team owns foundational infrastructure, application teams own microservice-specific resources
- **Operational consistency** through centralized log retention, security policies, and monitoring
- **Deployment safety** through independent lifecycles and clear resource ownership

---

## Additional Resources

- [AWS Multi-Account Strategy Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/)
- [AWS VPC Endpoint Services / PrivateLink Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)

---

## License

MIT License