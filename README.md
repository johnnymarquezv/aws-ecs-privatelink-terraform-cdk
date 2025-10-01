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

- **Terraform** provisions **core VPC networking infrastructure** — VPC, subnets, IGWs, NAT gateways — in a centralized **Networking Account**, providing a stable network foundation.
- **AWS CDK** provisions **microservices infrastructure** in separate **Microservices Accounts**:
    - ECS clusters, services, task definitions.
    - Each microservice exposes its API by provisioning **Network Load Balancers (NLBs)**.
    - CDK manages **VPC Endpoint Services** to expose these NLBs, acting as provider endpoints.
    - CDK also provisions interface VPC endpoints to consume **other microservices' VPC Endpoint Services**, enabling private, bidirectional communication between microservices across accounts.
    - **For this example**: CDK deploys a publicly available microservice (nginx) suitable for testing VPC endpoint connectivity.

This split keeps Terraform and AWS CDK **independent**, with Terraform managing shared networking, and CDK fully responsible for application exposure and inter-service connectivity.

---

## Architecture

### Multi-account roles

- **Networking Account:**
    - Owns the core VPC, subnets, routing, NAT gateways, and Internet Gateway.
    - Does **not** provision microservice exposure resources.

- **Microservices Accounts:**
    - Own ECS microservices, their NLBs, and corresponding **VPC Endpoint Services** (provider part).
    - Own the interface VPC endpoints to consume other microservices' exposed services (consumer part).
    - Enable cross-account private connectivity using AWS PrivateLink.

### Bidirectional microservices connectivity

- Microservices expose APIs through NLBs paired with VPC Endpoint Services (managed by CDK).
- Microservices consume APIs by creating interface VPC endpoints to connect to provider accounts' endpoint services.
- Communication is private, secure, and fully managed by CDK stacks independent of Terraform base networking.

### Networking and private connectivity

- Terraform provisions the foundational network without dependency on microservices infrastructure.
- CDK imports VPC and subnet constructs from Terraform outputs or parameter store but manages all service exposure and consumption resources.
- Cross-account resource policies and IAM roles secure PrivateLink connections.

---

## Project Structure

```
aws-infra-project/
├── terraform-base-infra/          # Terraform for core VPC/networking in Networking Account
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── cdk-microservices/             # AWS CDK (TypeScript) managing ECS services, NLBs, and VPC Endpoint Services
│   ├── bin/
│   │   └── app.ts                 # CDK app entry point
│   ├── lib/
│   │   └── microservices-stack.ts # ECS cluster, NLBs, provider & consumer VPC endpoint setup
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

Export key network outputs for CDK stacks:

```bash
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
```

### Step 2 – Microservices (AWS CDK, Microservices Accounts)

Deploy microservices stacks that handle both exposure (provider) and consumption (consumer):

```bash
cd ../cdk-microservices
npm install
cdk deploy -c vpcId=$VPC_ID \
           -c publicSubnetIds=$PUBLIC_SUBNETS \
           -c privateSubnetIds=$PRIVATE_SUBNETS
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

- **Terraform** provides consistent, stable base networking infrastructure shared across all accounts.
- **AWS CDK** offers rich, typed programming constructs to independently model microservices infrastructure with complex bidirectional connectivity needs.
- The clear boundary simplifies team responsibilities and deployment safety.

---

## Additional Resources

- [AWS Multi-Account Strategy Whitepaper](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/)
- [AWS VPC Endpoint Services / PrivateLink Documentation](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)

---

## License

MIT License