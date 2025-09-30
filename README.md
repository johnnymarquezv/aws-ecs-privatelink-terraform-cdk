# ECS Microservices with VPC Endpoints Using Terraform and AWS CDK (TypeScript)

This project demonstrates a hybrid Infrastructure as Code (IaC) approach on AWS:

**Base Infrastructure with Terraform (HCL)** to provision stable foundational resources including a VPC, subnets, internet gateway, and NAT gateways.

**Microservices Infrastructure with AWS CDK (TypeScript)** to build ECS microservices, Network Load Balancers, and interface VPC endpoints for secure, private communication.

## Project Structure
```
aws-infra-project/
├── terraform-base-infra/          # Terraform code for base networking and infra
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── cdk-microservices/             # AWS CDK in TypeScript for ECS microservices infra
│   ├── bin/
│   │   └── app.ts                 # CDK app entry point (bootstraps the app)
│   ├── lib/
│   │   └── microservices-stack.ts  # CDK stack defining ECS, NLB, VPC endpoints
│   ├── package.json              # Declares CDK dependencies and devDependencies
│   ├── tsconfig.json             # TypeScript project config
│   └── README.md                 # This file
└── microservice/                  # Sample microservice source code
    ├── Dockerfile                # Dockerfile for the containerized microservice
    ├── src/
    │   └── ...                  # Application source code
    └── README.md                # Microservice-specific docs
```

## Prerequisites
- Terraform v1.13+ installed  
  Suggestion: Use [tfenv](https://github.com/tfutils/tfenv) for easy Terraform version management.
- Node.js 22+ with NPM installed for AWS CDK development
- AWS CLI configured with appropriate permissions
- AWS CDK CLI installed (`npm install -g aws-cdk`)

## CDK Folder Structure Explanation: lib vs bin
- **bin/** folder: Contains the application entry point file (e.g. `app.ts`). This file boots up the CDK app, instantiates stacks, and triggers deployment/synthesis.
- **lib/** folder: Contains the infrastructure code—stack definitions and reusable constructs that define AWS resources and services used by your app.

This separation helps keep deployment orchestration (**bin**) distinct from infrastructure modeling (**lib**).

## Deployment Steps

### 1. Deploy Base Infrastructure with Terraform
```bash
cd terraform-base-infra
terraform init
terraform apply -auto-approve
```
Retrieve Terraform outputs for the CDK app:
```bash
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
```

### 2. Deploy Microservices Infrastructure with AWS CDK TypeScript
```bash
cd ../cdk-microservices
npm install
```
Deploy the CDK stack passing Terraform outputs as context values:
```bash
cdk deploy -c vpcId=$VPC_ID -c publicSubnetIds=$PUBLIC_SUBNETS -c privateSubnetIds=$PRIVATE_SUBNETS
```

## Features
- Modular base AWS network infrastructure provisioned with Terraform.
- ECS Fargate cluster and services deployed using AWS CDK in TypeScript.
- Network Load Balancer (NLB) with listeners and target groups configured.
- Interface VPC Endpoints (AWS PrivateLink) for ECS APIs (ecs-agent, ecs-telemetry, ecs).
- Security best practices including private subnets and no public IPs on ECS tasks.
- Clear separation of responsibilities between foundational infrastructure and application microservices.

## Why Hybrid Terraform + AWS CDK?
- **Terraform** is ideal for managing stable, foundational infrastructure with strong state management.
- **AWS CDK** enables rich object-oriented infrastructure modeling in TypeScript, allowing rapid iteration on application stacks.
- Combining both tools supports effective team workflows: DevOps focuses on Terraform base; developers manage microservices with AWS CDK.

## Project Development

### Updating Terraform Infrastructure
```bash
terraform plan
terraform apply
```

### Updating CDK Infrastructure
```bash
npm run build
cdk deploy
```

## Additional Resources
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [tfenv Terraform Version Manager](https://github.com/tfutils/tfenv)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)
- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [AWS VPC Interface Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/)

## License
This project is open source under the MIT License.
