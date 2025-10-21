# Multi-Account Microservices with AWS ECS, PrivateLink, Terraform, and CDK

A secure, scalable multi-account microservices architecture using AWS ECS, PrivateLink, Terraform, and AWS CDK (TypeScript).

## Links

- **Repository**: [GitHub Repository](https://github.com/johnnymarquezv/aws-ecs-privatelink-terraform-cdk)
- **Container Registry**: [GitHub Container Registry](https://github.com/johnnymarquezv/aws-ecs-privatelink-terraform-cdk/pkgs/container/aws-ecs-privatelink-terraform-cdk%2Fmicroservice)

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

#### Local Testing with curl

This section covers testing the microservice locally using curl commands.

##### Basic Service Testing

1. **Start the microservice**:
   ```bash
   cd microservice
   python app/main.py
   ```

2. **Test with curl**:
   ```bash
   # Test root endpoint
   curl http://localhost:8000/
   
   # Test health endpoint
   curl http://localhost:8000/health
   
   # Test readiness endpoint
   curl http://localhost:8000/ready
   
   # Test service status
   curl http://localhost:8000/status
   
   # Test metrics endpoint
   curl http://localhost:8000/metrics
   ```

### Local Kubernetes Development with Minikube

This section covers running the microservices locally using Minikube for development and testing.

#### Prerequisites

- **Minikube**: [Install Minikube](https://minikube.sigs.k8s.io/docs/start/)
- **kubectl**: [Install kubectl](https://kubernetes.io/docs/tasks/tools/)
- **Docker**: For building container images

#### Setup Minikube

1. **Start Minikube**:
   ```bash
   # Start minikube with sufficient resources
   minikube start --memory=4096 --cpus=2 --disk-size=20g
   
   # Enable ingress addon for LoadBalancer services
   minikube addons enable ingress
   ```

2. **Verify Minikube is running**:
   ```bash
   kubectl get nodes
   minikube status
   ```

#### Build and Deploy Microservices

1. **Build the Docker image**:
   ```bash
   cd microservice
   
   # Build the microservice image
   docker build -t microservice:latest .
   
   # Load the image into minikube
   minikube image load microservice:latest
   ```

2. **Deploy the microservices**:
   ```bash
   # Create namespace
   kubectl apply -f k8s/namespace.yaml
   
   # Deploy the API service provider
   kubectl apply -f k8s/api-service-provider.yaml
   
   # Deploy the API consumer
   kubectl apply -f k8s/api-consumer.yaml
   ```

3. **Verify deployments**:
   ```bash
   # Check pods are running
   kubectl get pods -n microservice-test
   
   # Check services
   kubectl get services -n microservice-test
   
   # Check deployments
   kubectl get deployments -n microservice-test
   ```

#### Access the Microservices

1. **Get service URLs**:
   ```bash
   # Get the consumer service URL (LoadBalancer)
   minikube service api-consumer -n microservice-test --url
   
   # Or use port forwarding for direct access
   kubectl port-forward service/api-consumer 8000:8000 -n microservice-test
   ```

2. **Test the services**:
   ```bash
   # Test the consumer service
   curl http://localhost:8000/
   curl http://localhost:8000/health
   curl http://localhost:8000/status
   
   # Test service-to-service communication
   curl -X POST http://localhost:8000/call/api-service \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

#### Development Workflow

1. **Make code changes**:
   ```bash
   # Edit your code in the microservice/ directory
   # Rebuild and reload the image
   docker build -t microservice:latest .
   minikube image load microservice:latest
   ```

2. **Restart deployments**:
   ```bash
   # Restart the deployments to pick up the new image
   kubectl rollout restart deployment/api-service-provider -n microservice-test
   kubectl rollout restart deployment/api-consumer -n microservice-test
   
   # Watch the rollout
   kubectl rollout status deployment/api-service-provider -n microservice-test
   kubectl rollout status deployment/api-consumer -n microservice-test
   ```

#### Monitoring and Debugging

1. **View logs**:
   ```bash
   # View logs for both services
   kubectl logs -f deployment/api-service-provider -n microservice-test
   kubectl logs -f deployment/api-consumer -n microservice-test
   ```

2. **Access service metrics**:
   ```bash
   # Port forward to access metrics
   kubectl port-forward service/api-consumer 8000:8000 -n microservice-test
   
   # Access Prometheus metrics
   curl http://localhost:8000/metrics
   ```

3. **Debug pods**:
   ```bash
   # Get pod details
   kubectl describe pod <pod-name> -n microservice-test
   
   # Execute commands in pod
   kubectl exec -it <pod-name> -n microservice-test -- /bin/bash
   ```

#### Cleanup

```bash
# Delete the microservices
kubectl delete -f k8s/api-consumer.yaml
kubectl delete -f k8s/api-service-provider.yaml
kubectl delete -f k8s/namespace.yaml

# Stop minikube
minikube stop

# Delete minikube cluster (optional)
minikube delete
```

#### Service Architecture

The local setup includes:

- **API Service Provider**: Core microservice that provides business logic
- **API Consumer**: Service that consumes the provider service
- **Service Discovery**: Consumer service discovers provider via Kubernetes DNS
- **Load Balancing**: Kubernetes services provide load balancing
- **Health Checks**: Liveness and readiness probes ensure service health
- **Metrics**: Prometheus-compatible metrics endpoint for monitoring

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

