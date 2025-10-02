#!/bin/bash

# CDK Provider Account Deployment Script
# This script deploys microservices that provide services to other accounts

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
SERVICE_NAME=${4:-"microservice"}
SERVICE_PORT=${5:-80}
SERVICE_IMAGE=${6:-"ghcr.io/your-org/microservice:latest"}
ALLOWED_ACCOUNTS=${7:-""}

print_header "CDK Provider Account Deployment"
print_header "==============================="
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "Service: $SERVICE_NAME"
print_status "Port: $SERVICE_PORT"
print_status "Image: $SERVICE_IMAGE"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "cdk-provider-account" ]; then
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

# Deploy CDK provider stack
deploy_provider() {
    print_header "Deploying CDK Provider Stack"
    
    cd cdk-provider-account
    
    # Install dependencies
    npm install
    
    # Set allowed accounts
    if [ -z "$ALLOWED_ACCOUNTS" ]; then
        ALLOWED_ACCOUNTS="123456789012,234567890123,345678901234,456789012345"
        print_warning "No allowed accounts specified. Using defaults: $ALLOWED_ACCOUNTS"
    fi
    
    # Deploy CDK stack
    print_status "Deploying provider stack..."
    cdk deploy ${SERVICE_NAME}-provider-stack \
        --context environment=$ENVIRONMENT \
        --context accountId=$ACCOUNT_ID \
        --context vpcId=$VPC_ID \
        --context publicSubnetIds="$PUBLIC_SUBNETS" \
        --context privateSubnetIds="$PRIVATE_SUBNETS" \
        --context baseDefaultSecurityGroupId="$BASE_DEFAULT_SECURITY_GROUP_ID" \
        --context basePrivateSecurityGroupId="$BASE_PRIVATE_SECURITY_GROUP_ID" \
        --context ecsTaskExecutionRoleArn="$ECS_TASK_EXECUTION_ROLE_ARN" \
        --context ecsTaskRoleArn="$ECS_TASK_ROLE_ARN" \
        --context ecsApplicationLogGroupName="$ECS_APPLICATION_LOG_GROUP_NAME" \
        --context microserviceName=$SERVICE_NAME \
        --context microservicePort=$SERVICE_PORT \
        --context microserviceImage=$SERVICE_IMAGE \
        --context allowedAccounts="[$ALLOWED_ACCOUNTS]" \
        --context serviceDescription="Provider service for $SERVICE_NAME"
    
    print_status "Provider deployment completed ✓"
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Provider Deployment"
    
    # Check ECS cluster
    aws ecs describe-clusters --clusters ${SERVICE_NAME}-cluster --region $REGION > /dev/null
    print_status "ECS cluster verification passed ✓"
    
    # Check ECS services
    aws ecs list-services --cluster ${SERVICE_NAME}-cluster --region $REGION > /dev/null
    print_status "ECS services verification passed ✓"
    
    # Check VPC endpoint services
    aws ec2 describe-vpc-endpoint-services --region $REGION --query 'ServiceNames[?contains(@, `'${SERVICE_NAME}'`)]' > /dev/null
    print_status "VPC endpoint services verification passed ✓"
    
    # Get VPC endpoint service ID for sharing
    VPC_ENDPOINT_SERVICE_ID=$(aws ec2 describe-vpc-endpoint-services --region $REGION --query 'ServiceNames[?contains(@, `'${SERVICE_NAME}'`)][0]' --output text)
    if [ "$VPC_ENDPOINT_SERVICE_ID" != "None" ] && [ ! -z "$VPC_ENDPOINT_SERVICE_ID" ]; then
        print_status "VPC Endpoint Service ID: $VPC_ENDPOINT_SERVICE_ID"
        echo "VPC_ENDPOINT_SERVICE_ID=$VPC_ENDPOINT_SERVICE_ID" > provider-outputs.env
    fi
}

# Main deployment function
main() {
    print_header "Starting CDK Provider Account Deployment"
    print_header "======================================="
    
    check_prerequisites
    get_account_id
    load_terraform_outputs
    bootstrap_cdk
    deploy_provider
    verify_deployment
    
    print_status "CDK provider account deployment completed successfully! 🎉"
    print_status "Provider service is ready to be consumed by other accounts"
    print_status "VPC Endpoint Service ID saved to provider-outputs.env"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [account-id] [service-name] [service-port] [service-image] [allowed-accounts]"
        echo ""
        echo "Arguments:"
        echo "  environment       - Environment (dev|staging|prod) [default: dev]"
        echo "  region            - AWS region [default: us-east-1]"
        echo "  account-id        - AWS account ID [default: current account]"
        echo "  service-name      - Name of the microservice [default: microservice]"
        echo "  service-port      - Port the service runs on [default: 80]"
        echo "  service-image     - Docker image for the service [default: nginx:alpine]"
        echo "  allowed-accounts  - Comma-separated allowed account IDs [default: 123456789012,234567890123,345678901234,456789012345]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 111111111111 user-service 8080 my-registry/user-service:latest"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
