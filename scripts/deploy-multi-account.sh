#!/bin/bash

# Multi-Account Deployment Script
# This script deploys the infrastructure across multiple AWS accounts

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
NETWORKING_ACCOUNT_ID=${3:-""}
MICROSERVICES_ACCOUNTS=${4:-""}

# Account configurations
declare -A ACCOUNTS=(
    ["networking"]="123456789012"
    ["microservices-1"]="234567890123"
    ["microservices-2"]="345678901234"
    ["microservices-3"]="456789012345"
)

# Override with provided values
if [ ! -z "$NETWORKING_ACCOUNT_ID" ]; then
    ACCOUNTS["networking"]="$NETWORKING_ACCOUNT_ID"
fi

if [ ! -z "$MICROSERVICES_ACCOUNTS" ]; then
    IFS=',' read -ra MICRO_ACCOUNTS <<< "$MICROSERVICES_ACCOUNTS"
    for i in "${!MICRO_ACCOUNTS[@]}"; do
        ACCOUNTS["microservices-$((i+1))"]="${MICRO_ACCOUNTS[i]}"
    done
fi

# Service configurations
declare -A SERVICES=(
    ["user-service"]="8080"
    ["notification-service"]="8081"
    ["payment-service"]="8082"
)

print_header "Multi-Account Microservices Deployment"
print_header "======================================"
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "Networking Account: ${ACCOUNTS[networking]}"
print_status "Microservices Accounts: ${ACCOUNTS[microservices-1]}, ${ACCOUNTS[microservices-2]}, ${ACCOUNTS[microservices-3]}"

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

# Bootstrap CDK in all accounts
bootstrap_accounts() {
    print_header "Bootstrapping CDK in all accounts..."
    
    for account_name in "${!ACCOUNTS[@]}"; do
        account_id="${ACCOUNTS[$account_name]}"
        
        print_status "Bootstrapping account: $account_name ($account_id)"
        
        # Check if profile exists
        if aws configure list-profiles | grep -q "^${account_name}$"; then
            cdk bootstrap aws://$account_id/$REGION \
                --profile $account_name \
                --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
                --trust-for-lookup false
        else
            print_warning "Profile $account_name not found. Using default credentials."
            cdk bootstrap aws://$account_id/$REGION \
                --cloudformation-execution-policies arn:aws:iam::aws:policy/AdministratorAccess \
                --trust-for-lookup false
        fi
    done
    
    print_status "CDK bootstrap completed ✓"
}

# Deploy networking account
deploy_networking() {
    print_header "Deploying Networking Account (${ACCOUNTS[networking]})"
    
    cd terraform-base-infra
    
    # Set AWS profile if it exists
    if aws configure list-profiles | grep -q "^networking$"; then
        export AWS_PROFILE=networking
    fi
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
aws_region = "$REGION"
account_id = "${ACCOUNTS[networking]}"
environment = "$ENVIRONMENT"

# Microservices accounts
microservices_accounts = [
    "${ACCOUNTS[microservices-1]}",
    "${ACCOUNTS[microservices-2]}",
    "${ACCOUNTS[microservices-3]}"
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
    terraform plan -var-file="terraform.tfvars"
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
    
    print_status "Networking deployment completed ✓"
    print_status "VPC ID: $VPC_ID"
    print_status "Exported all required outputs for CDK deployment"
    
    cd ..
}

# Deploy microservices accounts
deploy_microservices() {
    print_header "Deploying Microservices Accounts"
    
    cd cdk-microservices
    
    # Install dependencies
    npm install
    
    # Deploy each microservices account
    for account_name in "${!ACCOUNTS[@]}"; do
        if [[ $account_name == "networking" ]]; then
            continue
        fi
        
        account_id="${ACCOUNTS[$account_name]}"
        service_name="${account_name#microservices-}"
        
        print_status "Deploying $account_name ($account_id) - $service_name"
        
        # Set AWS profile if it exists
        if aws configure list-profiles | grep -q "^${account_name}$"; then
            export AWS_PROFILE=$account_name
        else
            print_warning "Profile $account_name not found. Using default credentials."
            unset AWS_PROFILE
        fi
        
        # Deploy microservices stack
        cdk deploy ${service_name}-stack \
            --context environment=$ENVIRONMENT \
            --context accountId=$account_id \
            --context vpcId=$VPC_ID \
            --context publicSubnetIds="$PUBLIC_SUBNETS" \
            --context privateSubnetIds="$PRIVATE_SUBNETS" \
            --context baseDefaultSecurityGroupId="$BASE_DEFAULT_SECURITY_GROUP_ID" \
            --context basePrivateSecurityGroupId="$BASE_PRIVATE_SECURITY_GROUP_ID" \
            --context ecsTaskExecutionRoleArn="$ECS_TASK_EXECUTION_ROLE_ARN" \
            --context ecsTaskRoleArn="$ECS_TASK_ROLE_ARN" \
            --context ecsApplicationLogGroupName="$ECS_APPLICATION_LOG_GROUP_NAME" \
            --context microserviceName=$service_name \
            --context microservicePort=${SERVICES[$service_name]:-80} \
            --context microserviceImage="nginx:alpine" \
            --context allowedAccounts="[${ACCOUNTS[networking]},${ACCOUNTS[microservices-1]},${ACCOUNTS[microservices-2]},${ACCOUNTS[microservices-3]}]"
        
        print_status "$account_name deployment completed ✓"
    done
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Deployment"
    
    for account_name in "${!ACCOUNTS[@]}"; do
        if [[ $account_name == "networking" ]]; then
            continue
        fi
        
        account_id="${ACCOUNTS[$account_name]}"
        service_name="${account_name#microservices-}"
        
        print_status "Verifying $account_name ($account_id)"
        
        # Set AWS profile if it exists
        if aws configure list-profiles | grep -q "^${account_name}$"; then
            export AWS_PROFILE=$account_name
        else
            unset AWS_PROFILE
        fi
        
        # Check ECS services
        aws ecs list-services --cluster ${service_name}-cluster --region $REGION
        
        # Check VPC endpoint services
        aws ec2 describe-vpc-endpoint-services --region $REGION --query 'ServiceNames[?contains(@, `'${service_name}'`)]'
        
        print_status "$account_name verification completed ✓"
    done
}

# Cleanup function
cleanup() {
    print_header "Cleaning up temporary files..."
    rm -f terraform-base-infra/terraform.tfvars
    print_status "Cleanup completed ✓"
}

# Main deployment function
main() {
    print_header "Starting Multi-Account Microservices Deployment"
    print_header "=============================================="
    
    # Check if we're in the right directory
    if [ ! -f "README.md" ] || [ ! -d "terraform-base-infra" ] || [ ! -d "cdk-microservices" ]; then
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    check_prerequisites
    bootstrap_accounts
    deploy_networking
    deploy_microservices
    verify_deployment
    cleanup
    
    print_status "Multi-account deployment completed successfully! 🎉"
    print_status "Your microservices are now running across multiple accounts with PrivateLink connectivity"
}

# Handle script arguments
case "${1:-}" in
    "networking")
        check_prerequisites
        deploy_networking
        ;;
    "microservices")
        if [ -z "$VPC_ID" ] || [ -z "$PUBLIC_SUBNETS" ] || [ -z "$PRIVATE_SUBNETS" ]; then
            print_error "Networking outputs not found. Please run 'terraform apply' first or set environment variables"
            exit 1
        fi
        check_prerequisites
        deploy_microservices
        ;;
    "bootstrap")
        check_prerequisites
        bootstrap_accounts
        ;;
    "verify")
        verify_deployment
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [networking|microservices|bootstrap|verify|help] [environment] [region] [networking-account-id] [microservices-account-ids]"
        echo ""
        echo "Commands:"
        echo "  networking     - Deploy only networking account"
        echo "  microservices  - Deploy only microservices accounts (requires networking outputs)"
        echo "  bootstrap      - Bootstrap CDK in all accounts"
        echo "  verify         - Verify deployment"
        echo "  help           - Show this help message"
        echo "  (no args)      - Deploy everything"
        echo ""
        echo "Arguments:"
        echo "  environment              - Environment (dev|staging|prod) [default: dev]"
        echo "  region                   - AWS region [default: us-east-1]"
        echo "  networking-account-id    - Networking account ID [default: 123456789012]"
        echo "  microservices-account-ids - Comma-separated microservices account IDs [default: 234567890123,345678901234,456789012345]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy everything with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 111111111111        # Deploy to prod with custom networking account"
        echo "  $0 dev us-east-1 111111111111 222222222222,333333333333  # Deploy with custom accounts"
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
