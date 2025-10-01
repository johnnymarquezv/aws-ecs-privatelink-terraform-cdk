#!/bin/bash

# Multi-Account Microservices Deployment Script
# This script deploys the Terraform base infrastructure and CDK microservices

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform 1.13+"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    if ! command -v cdk &> /dev/null; then
        print_error "AWS CDK CLI is not installed. Please run: npm install -g aws-cdk"
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install Node.js and npm"
        exit 1
    fi
    
    print_status "All prerequisites are installed ✓"
}

# Deploy Terraform base infrastructure
deploy_terraform() {
    print_status "Deploying Terraform base infrastructure..."
    
    cd terraform-base-infra
    
    # Initialize Terraform
    terraform init
    
    # Plan and apply
    terraform plan
    terraform apply -auto-approve
    
    # Export outputs for CDK
    export VPC_ID=$(terraform output -raw vpc_id)
    export PUBLIC_SUBNETS=$(terraform output -json public_subnet_ids)
    export PRIVATE_SUBNETS=$(terraform output -json private_subnet_ids)
    export BASE_DEFAULT_SECURITY_GROUP_ID=$(terraform output -raw base_default_security_group_id)
    export BASE_PRIVATE_SECURITY_GROUP_ID=$(terraform output -raw base_private_security_group_id)
    export ECS_TASK_EXECUTION_ROLE_ARN=$(terraform output -raw ecs_task_execution_role_arn)
    export ECS_TASK_ROLE_ARN=$(terraform output -raw ecs_task_role_arn)
    export ECS_APPLICATION_LOG_GROUP_NAME=$(terraform output -raw ecs_application_log_group_name)
    
    print_status "Terraform deployment completed ✓"
    print_status "VPC ID: $VPC_ID"
    print_status "Public Subnets: $PUBLIC_SUBNETS"
    print_status "Private Subnets: $PRIVATE_SUBNETS"
    print_status "Base Security Groups and IAM roles exported ✓"
    
    cd ..
}

# Deploy CDK microservices
deploy_cdk() {
    print_status "Deploying CDK microservices..."
    
    cd cdk-microservices
    
    # Install dependencies
    npm install
    
    # Deploy CDK stack
    cdk deploy -c vpcId=$VPC_ID \
               -c publicSubnetIds="$PUBLIC_SUBNETS" \
               -c privateSubnetIds="$PRIVATE_SUBNETS" \
               -c baseDefaultSecurityGroupId="$BASE_DEFAULT_SECURITY_GROUP_ID" \
               -c basePrivateSecurityGroupId="$BASE_PRIVATE_SECURITY_GROUP_ID" \
               -c ecsTaskExecutionRoleArn="$ECS_TASK_EXECUTION_ROLE_ARN" \
               -c ecsTaskRoleArn="$ECS_TASK_ROLE_ARN" \
               -c ecsApplicationLogGroupName="$ECS_APPLICATION_LOG_GROUP_NAME" \
               -c microserviceName="microservice" \
               -c microservicePort="80" \
               -c microserviceImage="nginx:alpine"
    
    print_status "CDK deployment completed ✓"
    
    cd ..
}

# Main deployment function
main() {
    print_status "Starting Multi-Account Microservices Deployment"
    print_status "=============================================="
    
    # Check if we're in the right directory
    if [ ! -f "README.md" ] || [ ! -d "terraform-base-infra" ] || [ ! -d "cdk-microservices" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    check_prerequisites
    deploy_terraform
    deploy_cdk
    
    print_status "Deployment completed successfully! 🎉"
    print_status "Your microservices are now running with PrivateLink connectivity"
}

# Handle script arguments
case "${1:-}" in
    "terraform")
        check_prerequisites
        deploy_terraform
        ;;
    "cdk")
        if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNETS" ] || [ -z "$PRIVATE_SUBNETS" ]; then
            print_error "Terraform outputs not found. Please run 'terraform apply' first or set environment variables"
            exit 1
        fi
        check_prerequisites
        deploy_cdk
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [terraform|cdk|help]"
        echo ""
        echo "Commands:"
        echo "  terraform  - Deploy only Terraform base infrastructure"
        echo "  cdk        - Deploy only CDK microservices (requires Terraform outputs)"
        echo "  help       - Show this help message"
        echo "  (no args)  - Deploy both Terraform and CDK"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac


