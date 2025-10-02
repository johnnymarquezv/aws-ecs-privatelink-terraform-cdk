#!/bin/bash

# CDK Consumer Account Deployment Script
# This script deploys microservices that consume services from other accounts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
ACCOUNT_ID=${3:-""}
SERVICE_NAME=${4:-"consumer"}
SERVICE_PORT=${5:-80}
SERVICE_IMAGE=${6:-"nginx:alpine"}
PROVIDER_SERVICES=${7:-""}

print_header "CDK Consumer Account Deployment"
print_header "==============================="
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "Service: $SERVICE_NAME"
print_status "Port: $SERVICE_PORT"
print_status "Image: $SERVICE_IMAGE"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "cdk-consumer-account" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v cdk &> /dev/null; then
        print_error "AWS CDK CLI is not installed. Please run: npm install -g aws-cdk"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install Node.js and npm"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    print_status "All prerequisites are installed ✓"
}

# Get account ID if not provided
get_account_id() {
    if [ -z "$ACCOUNT_ID" ]; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        print_status "Using current AWS account: $ACCOUNT_ID"
    else
        print_status "Using provided account ID: $ACCOUNT_ID"
    fi
}

# Load Terraform outputs
load_terraform_outputs() {
    if [ -f "terraform-outputs.env" ]; then
        print_status "Loading Terraform outputs..."
        source terraform-outputs.env
        print_status "Terraform outputs loaded ✓"
    else
        print_error "terraform-outputs.env not found. Please run deploy-terraform-account.sh first"
        exit 1
    fi
}

# Load provider outputs
load_provider_outputs() {
    if [ -f "provider-outputs.env" ]; then
        print_status "Loading provider outputs..."
        source provider-outputs.env
        print_status "Provider outputs loaded ✓"
    else
        print_warning "provider-outputs.env not found. You may need to provide VPC endpoint service IDs manually"
    fi
}

# Parse provider services
parse_provider_services() {
    if [ -z "$PROVIDER_SERVICES" ]; then
        if [ ! -z "$VPC_ENDPOINT_SERVICE_ID" ]; then
            # Use the provider service ID if available
            PROVIDER_SERVICES="[{\"serviceName\":\"provider-service\",\"vpcEndpointServiceId\":\"$VPC_ENDPOINT_SERVICE_ID\",\"port\":80}]"
            print_status "Using provider service from outputs: $VPC_ENDPOINT_SERVICE_ID"
        else
            print_warning "No provider services specified. Consumer will not connect to any external services."
            PROVIDER_SERVICES="[]"
        fi
    else
        print_status "Using provided provider services: $PROVIDER_SERVICES"
    fi
}

# Bootstrap CDK if needed
bootstrap_cdk() {
    print_status "Checking CDK bootstrap status..."
    
    if ! cdk list --quiet 2>/dev/null; then
        print_status "Bootstrapping CDK..."
        cdk bootstrap aws://$ACCOUNT_ID/$REGION \
            --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
            --trust-for-lookup false
        print_status "CDK bootstrap completed ✓"
    else
        print_status "CDK already bootstrapped ✓"
    fi
}

# Deploy CDK consumer stack
deploy_consumer() {
    print_header "Deploying CDK Consumer Stack"
    
    cd cdk-consumer-account
    
    # Install dependencies
    npm install
    
    # Deploy CDK stack
    print_status "Deploying consumer stack..."
    cdk deploy ${SERVICE_NAME}-consumer-stack \
        --context environment=$ENVIRONMENT \
        --context accountId=$ACCOUNT_ID \
        --context vpcId=$VPC_ID \
        --context privateSubnetIds="$PRIVATE_SUBNETS" \
        --context basePrivateSecurityGroupId="$BASE_PRIVATE_SECURITY_GROUP_ID" \
        --context ecsTaskExecutionRoleArn="$ECS_TASK_EXECUTION_ROLE_ARN" \
        --context ecsTaskRoleArn="$ECS_TASK_ROLE_ARN" \
        --context ecsApplicationLogGroupName="$ECS_APPLICATION_LOG_GROUP_NAME" \
        --context microserviceName=$SERVICE_NAME \
        --context microservicePort=$SERVICE_PORT \
        --context microserviceImage=$SERVICE_IMAGE \
        --context consumerEndpointServices="$PROVIDER_SERVICES"
    
    print_status "Consumer deployment completed ✓"
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Consumer Deployment"
    
    # Check ECS cluster
    aws ecs describe-clusters --clusters ${SERVICE_NAME}-consumer-cluster --region $REGION > /dev/null
    print_status "ECS cluster verification passed ✓"
    
    # Check ECS services
    aws ecs list-services --cluster ${SERVICE_NAME}-consumer-cluster --region $REGION > /dev/null
    print_status "ECS services verification passed ✓"
    
    # Check VPC endpoints
    aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION > /dev/null
    print_status "VPC endpoints verification passed ✓"
}

# Main deployment function
main() {
    print_header "Starting CDK Consumer Account Deployment"
    print_header "======================================="
    
    check_prerequisites
    get_account_id
    load_terraform_outputs
    load_provider_outputs
    parse_provider_services
    bootstrap_cdk
    deploy_consumer
    verify_deployment
    
    print_status "CDK consumer account deployment completed successfully! 🎉"
    print_status "Consumer service is ready to consume services from other accounts"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [account-id] [service-name] [service-port] [service-image] [provider-services]"
        echo ""
        echo "Arguments:"
        echo "  environment        - Environment (dev|staging|prod) [default: dev]"
        echo "  region             - AWS region [default: us-east-1]"
        echo "  account-id         - AWS account ID [default: current account]"
        echo "  service-name       - Name of the consumer service [default: consumer]"
        echo "  service-port       - Port the service runs on [default: 80]"
        echo "  service-image      - Docker image for the service [default: nginx:alpine]"
        echo "  provider-services  - JSON array of provider services to consume [default: from provider-outputs.env]"
        echo ""
        echo "Provider Services JSON Format:"
        echo '  [{"serviceName":"service1","vpcEndpointServiceId":"vpce-svc-123","port":80}]'
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 111111111111 api-consumer 8080 my-registry/api-consumer:latest"
        echo '  $0 dev us-east-1 111111111111 consumer 80 nginx:alpine "[{\"serviceName\":\"api-service\",\"vpcEndpointServiceId\":\"vpce-svc-1234567890abcdef0\",\"port\":80}]"'
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
