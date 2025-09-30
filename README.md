# ECS Microservices with VPC Endpoints Using Terraform and AWS CDK (TypeScript)

This project demonstrates a hybrid Infrastructure as Code (IaC) approach on AWS:

- **Base Infrastructure** with Terraform (HCL) to provision stable foundational resources including a VPC, subnets, internet gateway, and NAT gateways.
- **Microservices Infrastructure** with AWS CDK (TypeScript) to build ECS microservices, Network Load Balancers, and interface VPC endpoints for secure, private communication.

---

## Project Structure

aws-infra-project/
├── terraform-base-infra/ # Terraform code for base networking and infra
│ ├── main.tf
│ ├── variables.tf
│ ├── outputs.tf
│ └── provider.tf
├── cdk-microservices/ # AWS CDK in TypeScript for ECS microservices infra
│ ├── bin/
│ │ └── app.ts # CDK app entry point (bootstraps the app)
│ ├── lib/
│ │ └── microservices-stack.ts # CDK stack defining ECS, NLB, VPC endpoints
│ ├── package.json # Declares CDK dependencies and devDependencies
│ ├── tsconfig.json # TypeScript project config
│ └── README.md # This file
└── microservice/ # Sample microservice source code
├── Dockerfile # Dockerfile for the containerized microservice
├── src/
│ └── ... # Application source code
└── README.md # Microservice-specific docs

text

---

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) v1.13+ installed  
  _Suggestion:_ Use [tfenv](https://github.com/tfutils/tfenv) for easy Terraform version management.
- [Node.js](https://nodejs.org/en/download/) 22+ with NPM installed for AWS CDK development
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate permissions
- [AWS CDK](https://docs.aws.amazon.com/cdk/latest/guide/getting_started.html) CLI installed (`npm install -g aws-cdk`)

---

## CDK Folder Structure Explanation: `lib` vs `bin`

- **`bin/` folder:** Contains the application entry point file (e.g. `app.ts`). This file boots up the CDK app, instantiates stacks, and triggers deployment/synthesis.
- **`lib/` folder:** Contains the infrastructure code—stack definitions and reusable constructs that define AWS resources and services used by your app.

This separation helps keep deployment orchestration (`bin`) distinct from infrastructure modeling (`lib`).

---

## Deployment Steps

### 1. Deploy Base Infrastructure with Terraform

cd terraform-base-infra
terraform init
terraform apply -auto-approve

text

Retrieve Terraform outputs for the CDK app:

export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)

text

### 2. Deploy Microservices Infrastructure with AWS CDK TypeScript

cd ../cdk-microservices
npm install

text

Deploy the CDK stack passing Terraform outputs as context values:

cdk deploy -c vpcId=$VPC_ID -c publicSubnetIds=$PUBLIC_SUBNETS -c privateSubnetIds=$PRIVATE_SUBNETS

text

---

## Features

- Modular base AWS network infrastructure provisioned with Terraform.
- ECS Fargate cluster and services deployed using AWS CDK in TypeScript.
- Network Load Balancer (NLB) with listeners and target groups configured.
- Interface VPC Endpoints (AWS PrivateLink) for ECS APIs (`ecs-agent`, `ecs-telemetry`, `ecs`).
- Security best practices including private subnets and no public IPs on ECS tasks.
- Clear separation of responsibilities between foundational infrastructure and application microservices.

---

## Multi-Account Architecture with Microservices, NLB, and VPC Endpoint Services

### Overview

For organizations scaling their AWS environment, a **multi-account strategy** is a best practice to enhance security, governance, operational scalability, and cost management. This project can be extended to support such multi-account environments where different AWS accounts serve specific roles, including:

- **Networking Account:** Central VPC, shared services, and inter-account connectivity.
- **Microservices Accounts:** Dedicated accounts hosting microservices deployed on ECS.
- **Security and Compliance Accounts:** Managing centralized logging, auditing, and security tooling.

---

### Architecture

In a multi-account setup supporting ECS microservices interconnected securely:

1. **Core VPC and Networking Infrastructure**
    - Deployed in a dedicated **Networking Account**.
    - Hosts the central VPC with subnets, routing, NAT gateways.
    - Exposes **VPC Endpoint Services** representing microservices via **Network Load Balancers (NLB)**.

2. **Microservices in Separate Accounts**
    - Each microservice or group of related services deployed in its own AWS account (Microservices Account).
    - Microservices expose their APIs through **NLBs**, registered as **VPC Endpoint Services** in the Networking Account.
    - Communication between accounts uses **interface VPC endpoints** to privately consume these VPC endpoint services.
    - This ensures all microservice communication remains on the AWS private network, avoiding public internet exposure.

3. **Cross-Account Role and Permissions**
    - Proper IAM roles and policies established to allow cross-account VPC endpoint service creation and consumption.
    - Use of AWS Organizations and Service Control Policies (SCPs) for governance.

---

### Benefits

- **Isolation and Security:** Specific workload and network boundary per account improves security posture and compliance.
- **Cost Allocation and Tracking:** Costs naturally segregate per account, aiding billing transparency.
- **Operational Scalability:** Independent teams can manage their microservices accounts autonomously.
- **Network Efficiency:** Traffic routed privately over AWS backbone via VPC endpoints and NLBs.

---

### Implementation Considerations

- **Terraform and AWS CDK Deployment**  
  Use Terraform to provision shared networking resources including the VPC and VPC Endpoint Services in the Networking Account.  
  Use AWS CDK to deploy ECS clusters and services in Microservices Accounts, importing necessary VPC endpoint ARNs or DNS entries as environment variables or deployment parameters.

- **Resource Sharing & Discovery**  
  Use AWS Resource Access Manager (RAM) or DNS-based service discovery to publish microservices across accounts.

- **Security & Compliance**  
  Enforce least privilege IAM roles and leverage AWS Control Tower or AWS Organizations to enforce guardrails across accounts.

---

### References for Further Reading

- [Organizing Your AWS Environment Using Multiple Accounts (AWS Whitepaper)](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)
- [AWS Multi-Account Strategy and Landing Zone](https://dzone.com/articles/aws-multi-account-strategy-and-landing-zone)
- [Managing Cross-Account Serverless Microservices (AWS Blog)](https://aws.amazon.com/blogs/compute/managing-cross-account-serverless-microservices/)
- [Using VPC Endpoint Services to Privately Expose Applications Across AWS Accounts](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)

---

## Why Hybrid Terraform + AWS CDK?

- Terraform is ideal for managing stable, foundational infrastructure with strong state management.
- AWS CDK enables rich object-oriented infrastructure modeling in TypeScript, allowing rapid iteration on application stacks.
- Combining both tools supports effective team workflows: DevOps focuses on Terraform base; developers manage microservices with AWS CDK.

---

## Project Development

### Updating Terraform Infrastructure

Make changes in the `terraform-base-infra` folder, then run:

terraform plan
terraform apply

text

### Updating CDK Infrastructure

Modify code in `cdk-microservices/lib`, then run:

npm run build
cdk deploy

text

---

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [tfenv Terraform Version Manager](https://github.com/tfutils/tfenv)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)
- [Amazon ECS Developer Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)
- [AWS VPC Interface Endpoints](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-endpoints.html)

---

## License

This project is open source under the MIT License.

---
