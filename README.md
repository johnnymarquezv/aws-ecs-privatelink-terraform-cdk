# ECS Microservices with PrivateLink using Terraform and AWS CDK (TypeScript)

A hybrid, multi-account AWS architecture demonstrating secure microservices deployment across isolated AWS accounts using infrastructure as code.

## Architecture Overview

This repository demonstrates a secure microservices setup across multiple AWS accounts:
- **Terraform** builds and owns shared networking infrastructure in a centralized Networking Account
- **AWS CDK (TypeScript)** builds and owns ECS microservices stacks in separate Application Accounts
- **Cross-account private connectivity** is implemented with NLB-backed VPC Endpoint Services (AWS PrivateLink)

## Key Components

### Networking Account (Terraform)
- Core VPC, subnets, route tables, IGW/NAT Gateway
- VPC Endpoint Services fronted by Network Load Balancers (NLB)
- Optional shared security services and centralized logging
- Provides stable networking foundation for all application accounts

### Application Accounts (AWS CDK)
- ECS clusters, services, and task definitions
- Each service fronted by an NLB and registered as a VPC Endpoint Service (when exposed cross-account)
- Interface VPC Endpoints to consume other services privately
- Independent deployment lifecycle per microservice

## Network Flow

```
Client Microservice → Interface VPC Endpoint → PrivateLink → NLB → Target Microservice (ECS Tasks)
```

**Security Benefits:**
- No public internet exposure
- Traffic stays on AWS backbone
- Cross-account isolation with least-privilege access

## Project Structure

```
aws-infra-project/
├── terraform-base-infra/          # Core VPC/networking (Networking Account)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── provider.tf
├── cdk-microservices/             # ECS services (Application Accounts)
│   ├── bin/
│   │   └── app.ts                 # CDK app entry point
│   ├── lib/
│   │   └── microservices-stack.ts # Stack definitions
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
└── microservice/                  # Example service implementation
    ├── Dockerfile
    ├── requirements.txt
    ├── app/
    │   ├── main.py
    │   └── routers/hello.py
    └── README.md
```

## Prerequisites

- **Terraform** 1.13+ (recommend using [tfenv](https://github.com/tfutils/tfenv) for version management)
- **Node.js** 22+ and npm
- **AWS CLI** configured for each target account
- **AWS CDK CLI** installed globally: `npm install -g aws-cdk`

## CDK Folder Structure

### `bin/` Directory
- Entry point of the CDK application (e.g., `app.ts`)
- Creates the CDK App instance
- Reads context parameters and environment variables
- Instantiates stack classes

### `lib/` Directory
- Contains stack and construct definitions
- The actual infrastructure modeled as code
- Reusable components and patterns

This separation keeps orchestration logic distinct from infrastructure definitions.

## Deployment Workflow

### Step 1: Deploy Networking Infrastructure (Terraform)

```bash
cd terraform-base-infra
terraform init
terraform apply -auto-approve
```

**Capture outputs for use in microservices deployment:**

```bash
export VPC_ID=$(terraform output -raw vpc_id)
export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
export SERVICE1_ENDPOINT_SERVICE_NAME=$(terraform output -raw service1_endpoint_service_name)
```

### Step 2: Deploy Microservices (AWS CDK)

```bash
cd ../cdk-microservices
npm install

# Bootstrap CDK (once per account/region)
cdk bootstrap aws://<account-id>/<region>

# Deploy with context variables
cdk deploy \
  -c vpcId=$VPC_ID \
  -c publicSubnetIds=$PUBLIC_SUBNETS \
  -c privateSubnetIds=$PRIVATE_SUBNETS
```

**Important Notes:**
- Pass cross-account endpoint service names via context or environment variables
- Configure resource policies on VPC Endpoint Services to allow consumer accounts
- Consider using SSM Parameter Store or Secrets Manager for sharing configuration

## Security and Governance

- **Cross-account IAM roles** with least-privilege policies
- **Resource policies** on VPC Endpoint Services for explicit allowlisting
- **AWS Organizations and SCPs** for organizational guardrails
- **Centralized logging** options (CloudWatch, OpenSearch, third-party solutions)

## Development Workflow

### Terraform (Networking Account)
- Modify VPC/network modules as infrastructure evolves
- Maintain stable outputs to avoid breaking consumer stacks
- Use versioned modules for repeatability

### CDK (Application Accounts)
- Add new services as stacks or constructs under `lib/`
- Reuse common patterns for task definitions, logging, security groups
- Leverage TypeScript for type safety and IDE support

### Local Service Development

Example using Python/FastAPI:

```bash
cd microservice
docker build -t ecs-python-microservice .
docker run -p 8000:8000 ecs-python-microservice
```

## Why Hybrid Terraform + CDK?

### Terraform Advantages
- Excellent for long-lived, shared infrastructure
- Mature state management and workflow
- Strong provider ecosystem

### AWS CDK Advantages
- Fast iteration on application stacks
- TypeScript provides strong typing and IDE support
- Reusable constructs and patterns
- Native AWS service integration

### Combined Benefits
- Independent pipelines reduce blast radius
- Team autonomy with separated state domains
- Right tool for the right job

## Additional Resources

- [AWS Multi-Account Best Practices](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/organizing-your-aws-environment.html)
- [AWS VPC Interface Endpoints / PrivateLink](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS CDK Developer Guide](https://docs.aws.amazon.com/cdk/latest/guide/home.html)

## License

MIT