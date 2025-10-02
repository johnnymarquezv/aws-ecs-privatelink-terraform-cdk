#!/bin/bash

# Terraform Account Deployment Script
# This script deploys the networking infrastructure using Terraform

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
MICROSERVICES_ACCOUNTS=${4:-""}

print_header "Terraform Account Deployment"
print_header "============================"
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "terraform-base-infra" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check prerequisites
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

# Get microservices accounts if not provided
get_microservices_accounts() {
    if [ -z "$MICROSERVICES_ACCOUNTS" ]; then
        print_warning "No microservices accounts provided. Using defaults."
        MICROSERVICES_ACCOUNTS="234567890123,345678901234,456789012345"
    fi
    print_status "Microservices accounts: $MICROSERVICES_ACCOUNTS"
}

# Deploy Terraform infrastructure
deploy_terraform() {
    print_header "Deploying Terraform Infrastructure"
    
    cd terraform-base-infra
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
aws_region = "$REGION"
account_id = "$ACCOUNT_ID"
environment = "$ENVIRONMENT"

# Microservices accounts
microservices_accounts = [
    $(echo $MICROSERVICES_ACCOUNTS | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//')
]

# VPC configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
isolated_subnet_cidrs = ["10.0.5.0/28", "10.0.6.0/28"]

# Cross-account external ID
cross_account_external_id = "multi-account-${ENVIRONMENT}-$(date +%s)"
EOF
    
    # Plan and apply
    print_status "Planning Terraform deployment..."
    terraform plan -var-file="terraform.tfvars"
    
    print_status "Applying Terraform configuration..."
    terraform apply -var-file="terraform.tfvars" -auto-approve
    
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
    print_status "Exported all required outputs for CDK deployment"
    
    # Save outputs to file for other scripts
    cat > ../terraform-outputs.env << EOF
export VPC_ID="$VPC_ID"
export PUBLIC_SUBNETS='$PUBLIC_SUBNETS'
export PRIVATE_SUBNETS='$PRIVATE_SUBNETS'
export BASE_DEFAULT_SECURITY_GROUP_ID="$BASE_DEFAULT_SECURITY_GROUP_ID"
export BASE_PRIVATE_SECURITY_GROUP_ID="$BASE_PRIVATE_SECURITY_GROUP_ID"
export ECS_TASK_EXECUTION_ROLE_ARN="$ECS_TASK_EXECUTION_ROLE_ARN"
export ECS_TASK_ROLE_ARN="$ECS_TASK_ROLE_ARN"
export ECS_APPLICATION_LOG_GROUP_NAME="$ECS_APPLICATION_LOG_GROUP_NAME"
EOF
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Terraform Deployment"
    
    cd terraform-base-infra
    
    # Check VPC
    aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $REGION > /dev/null
    print_status "VPC verification passed ✓"
    
    # Check subnets
    aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION > /dev/null
    print_status "Subnets verification passed ✓"
    
    # Check security groups
    aws ec2 describe-security-groups --group-ids $BASE_DEFAULT_SECURITY_GROUP_ID --region $REGION > /dev/null
    print_status "Security groups verification passed ✓"
    
    # Check VPC endpoints
    aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION > /dev/null
    print_status "VPC endpoints verification passed ✓"
    
    cd ..
}

# Main deployment function
main() {
    print_header "Starting Terraform Account Deployment"
    print_header "====================================="
    
    check_prerequisites
    get_account_id
    get_microservices_accounts
    deploy_terraform
    verify_deployment
    
    print_status "Terraform account deployment completed successfully! 🎉"
    print_status "Networking infrastructure is ready for CDK deployments"
    print_status "Outputs saved to terraform-outputs.env for use by other scripts"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [account-id] [microservices-accounts]"
        echo ""
        echo "Arguments:"
        echo "  environment              - Environment (dev|staging|prod) [default: dev]"
        echo "  region                   - AWS region [default: us-east-1]"
        echo "  account-id               - AWS account ID [default: current account]"
        echo "  microservices-accounts  - Comma-separated microservices account IDs [default: 234567890123,345678901234,456789012345]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 111111111111        # Deploy to prod with specific account"
        echo "  $0 dev us-east-1 111111111111 222222222222,333333333333  # Deploy with custom microservices accounts"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
