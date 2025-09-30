# Multi-Account Project with Bidirectional Intercommunicating Microservices Using ECS, PrivateLink, Terraform, and AWS CDK (TypeScript)

This project implements a scalable, secure multi-account AWS architecture following the principle of **bidirectional intercommunication** among microservices deployed on ECS. It uses Terraform for foundational networking and AWS CDK (TypeScript) for application stacks, empowering private connectivity via AWS PrivateLink.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
    - [Multi-account roles](#multi-account-roles)
    - [Bidirectional microservices intercommunication](#bidirectional-microservices-intercommunication)
    - [Networking and private connectivity](#networking-and-private-connectivity)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Folder Roles in AWS CDK (Lib vs Bin)](#folder-roles-in-aws-cdk-lib-vs-bin)
- [Deployment Workflow](#deployment-workflow)
    - [Terraform in Networking Account](#networking-account-terraform)
    - [CDK in Microservices Accounts](#microservices-accounts-aws-cdk)
- [Development Process](#development-process)
- [Why Hybrid Terraform + CDK?](#why-hybrid-terraform--aws-cdk)
- [Additional Resources](#additional-resources)
- [License](#license)

---

## Overview

- Foundational network (VPC, subnets, routing, VPC Endpoint Services) provisioned via Terraform in a **Networking Account**.
- Microservices deployed on ECS via AWS CDK in **separate Microservices Accounts**.
- Bidirectional microservice communication achieved via **Network Load Balancers (NLBs)** exposed through **interface VPC Endpoints (AWS PrivateLink)**.
- Strong security enforced by private cross-account connectivity without Internet exposure.

---

## Architecture

### Multi-account roles

- **Networking Account:** Hosts core network infrastructure and exposes microservices as VPC Endpoint Services.
- **Microservices Accounts:** Host ECS microservices fronted by NLBs, consume each other's services via interface VPC endpoints enabling bidirectional communication.

### Bidirectional intercommunication

- Services in each account publish their APIs via NLBs.
- Each service registers its NLB as a VPC Endpoint Service in the Networking Account.
- Microservices consume each other's services securely across accounts over AWS backbone using interface VPC endpoints.
- This design avoids any public internet exposure and supports high performance private traffic flows.

### Networking and private connectivity

- Terraform provisions the VPC, IGW, NAT Gateways, subnets, route tables, and VPC Endpoint Services.
- AWS CDK provisions ECS clusters, services, task definitions, and VPC endpoint interfaces for consuming other accounts' services.
- Cross-account IAM roles, resource policies, and AWS Organizations SCPs govern permissions and security.

---

## Project Structure

```
aws-infra-project/
├── terraform-base-infra/          # Terraform for core VPC/networking in Networking Account
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── cdk-microservices/             # AWS CDK (TypeScript) ECS microservices per account
│   ├── bin/
│   │   └── app.ts                 # CDK app entry point
│   ├── lib/
│   │   └── microservices-stack.ts # ECS, NLB, VPC endpoints constructs
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
└── microservice/                  # Sample microservice source code (containerized)
    ├── Dockerfile
    ├── app/
    └── README.md
```

---

## Prerequisites

- Terraform 1.13+ (recommended use of [tfenv](https://github.com/tfutils/tfenv))
- Node.js 22+ and npm
- AWS CLI configured with valid profiles for all involved accounts
- AWS CDK CLI installed globally (`npm install -g aws-cdk`)

---

## Folder Roles in AWS CDK (Lib vs Bin)

- **bin/**: CDK application entry point, responsible for reading context/parameters and instantiating stacks.
- **lib/**: Stack and reusable construct definitions representing infrastructure components.

---

## Deployment Workflow

### Networking Account (Terraform)

Deploy core networking:

```bash
cd terraform-base-infra
terraform init
terraform apply -auto-approve
```

Export outputs providing networking context for microservices accounts:

```bash
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
```

### Microservices Accounts (AWS CDK)

Deploy microservices stacks in each account with:

```bash
cd ../cdk-microservices
npm install
cdk deploy -c vpcId=$VPC_ID \
  -c publicSubnetIds=$PUBLIC_SUBNETS \
  -c privateSubnetIds=$PRIVATE_SUBNETS
```

Repeat per microservices account with respective credentials.

---

## Development Process

- Modify and deploy foundational infra independently in Terraform.
- Develop and deploy application stacks per account using AWS CDK.
- Maintain clear versioning and stable interfaces for cross-account resource consumption.

---

## Why Hybrid Terraform + AWS CDK?

- Terraform excels at managing centralized, long-lived infrastructure consistently.
- AWS CDK enables rapid iteration and strongly typed infrastructure coding in TypeScript for application stacks.
- Separation of concerns supports multiple teams and improves deployment safety.

---

## Additional Resources

- [AWS Multi-Account Strategy](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/)
- [AWS VPC Endpoint Services (PrivateLink)](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)

---

## License

MIT License