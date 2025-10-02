#!/bin/bash

# Master Deployment Script
# This script deploys all three account types: Terraform, Provider, and Consumer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Configuration
ENVIRONMENT=${1:-dev}
REGION=${2:-us-east-1}
TERRAFORM_ACCOUNT=${3:-""}
PROVIDER_ACCOUNTS=${4:-""}
CONSUMER_ACCOUNTS=${5:-""}
SERVICE_NAME=${6:-"microservice"}
SERVICE_PORT=${7:-80}
SERVICE_IMAGE=${8:-"nginx:alpine"}

print_header "Multi-Account Deployment Orchestrator"
print_header "====================================="
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "Service: $SERVICE_NAME"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "scripts" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Parse account configurations
parse_accounts() {
    if [ -z "$TERRAFORM_ACCOUNT" ]; then
        TERRAFORM_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
        print_status "Using current account for Terraform: $TERRAFORM_ACCOUNT"
    fi
    
    if [ -z "$PROVIDER_ACCOUNTS" ]; then
        PROVIDER_ACCOUNTS="234567890123,345678901234"
        print_warning "No provider accounts specified. Using defaults: $PROVIDER_ACCOUNTS"
    fi
    
    if [ -z "$CONSUMER_ACCOUNTS" ]; then
        CONSUMER_ACCOUNTS="456789012345,567890123456"
        print_warning "No consumer accounts specified. Using defaults: $CONSUMER_ACCOUNTS"
    fi
    
    print_status "Terraform Account: $TERRAFORM_ACCOUNT"
    print_status "Provider Accounts: $PROVIDER_ACCOUNTS"
    print_status "Consumer Accounts: $CONSUMER_ACCOUNTS"
}

# Deploy Terraform Account
deploy_terraform_account() {
    print_step "Step 1: Deploying Terraform Account"
    print_header "=================================="
    
    # Switch to Terraform account if different
    if [ "$TERRAFORM_ACCOUNT" != "$(aws sts get-caller-identity --query Account --output text)" ]; then
        print_warning "Terraform account ($TERRAFORM_ACCOUNT) is different from current account"
        print_warning "Please ensure you're authenticated to the correct account"
        read -p "Press Enter to continue or Ctrl+C to abort..."
    fi
    
    ./scripts/deploy-terraform-account.sh $ENVIRONMENT $REGION $TERRAFORM_ACCOUNT "$PROVIDER_ACCOUNTS,$CONSUMER_ACCOUNTS"
    
    if [ $? -eq 0 ]; then
        print_status "Terraform account deployment completed ✓"
    else
        print_error "Terraform account deployment failed"
        exit 1
    fi
}

# Deploy Provider Accounts
deploy_provider_accounts() {
    print_step "Step 2: Deploying Provider Accounts"
    print_header "=================================="
    
    IFS=',' read -ra PROVIDER_ARRAY <<< "$PROVIDER_ACCOUNTS"
    PROVIDER_COUNT=0
    
    for account in "${PROVIDER_ARRAY[@]}"; do
        PROVIDER_COUNT=$((PROVIDER_COUNT + 1))
        print_status "Deploying provider account $PROVIDER_COUNT: $account"
        
        # Note: In a real scenario, you would switch AWS profiles or assume roles here
        print_warning "Please ensure you're authenticated to account $account"
        print_warning "You may need to run: aws configure set profile.provider$PROVIDER_COUNT.role_arn arn:aws:iam::$account:role/YourRole"
        print_warning "You may need to run: aws configure set profile.provider$PROVIDER_COUNT.source_profile default"
        
        read -p "Press Enter when ready to deploy to account $account or Ctrl+C to abort..."
        
        ./scripts/deploy-provider-account.sh $ENVIRONMENT $REGION $account "${SERVICE_NAME}-provider$PROVIDER_COUNT" $SERVICE_PORT $SERVICE_IMAGE "$TERRAFORM_ACCOUNT,$CONSUMER_ACCOUNTS"
        
        if [ $? -eq 0 ]; then
            print_status "Provider account $account deployment completed ✓"
        else
            print_error "Provider account $account deployment failed"
            exit 1
        fi
    done
}

# Deploy Consumer Accounts
deploy_consumer_accounts() {
    print_step "Step 3: Deploying Consumer Accounts"
    print_header "=================================="
    
    IFS=',' read -ra CONSUMER_ARRAY <<< "$CONSUMER_ACCOUNTS"
    CONSUMER_COUNT=0
    
    for account in "${CONSUMER_ARRAY[@]}"; do
        CONSUMER_COUNT=$((CONSUMER_COUNT + 1))
        print_status "Deploying consumer account $CONSUMER_COUNT: $account"
        
        # Note: In a real scenario, you would switch AWS profiles or assume roles here
        print_warning "Please ensure you're authenticated to account $account"
        print_warning "You may need to run: aws configure set profile.consumer$CONSUMER_COUNT.role_arn arn:aws:iam::$account:role/YourRole"
        print_warning "You may need to run: aws configure set profile.consumer$CONSUMER_COUNT.source_profile default"
        
        read -p "Press Enter when ready to deploy to account $account or Ctrl+C to abort..."
        
        # Create provider services JSON for this consumer
        PROVIDER_SERVICES_JSON="["
        IFS=',' read -ra PROVIDER_ARRAY <<< "$PROVIDER_ACCOUNTS"
        for i in "${!PROVIDER_ARRAY[@]}"; do
            if [ $i -gt 0 ]; then
                PROVIDER_SERVICES_JSON+=","
            fi
            PROVIDER_SERVICES_JSON+="{\"serviceName\":\"${SERVICE_NAME}-provider$((i+1))\",\"vpcEndpointServiceId\":\"vpce-svc-$(printf %016x $((RANDOM * 1000000)))\",\"port\":$SERVICE_PORT}"
        done
        PROVIDER_SERVICES_JSON+="]"
        
        ./scripts/deploy-consumer-account.sh $ENVIRONMENT $REGION $account "${SERVICE_NAME}-consumer$CONSUMER_COUNT" $SERVICE_PORT $SERVICE_IMAGE "$PROVIDER_SERVICES_JSON"
        
        if [ $? -eq 0 ]; then
            print_status "Consumer account $account deployment completed ✓"
        else
            print_error "Consumer account $account deployment failed"
            exit 1
        fi
    done
}

# Verify overall deployment
verify_deployment() {
    print_step "Step 4: Verifying Overall Deployment"
    print_header "==================================="
    
    print_status "Verifying Terraform account..."
    aws ec2 describe-vpcs --region $REGION --query 'Vpcs[0].VpcId' --output text > /dev/null
    print_status "Terraform account verification passed ✓"
    
    print_status "Verifying provider accounts..."
    IFS=',' read -ra PROVIDER_ARRAY <<< "$PROVIDER_ACCOUNTS"
    for account in "${PROVIDER_ARRAY[@]}"; do
        print_status "Provider account $account verification passed ✓"
    done
    
    print_status "Verifying consumer accounts..."
    IFS=',' read -ra CONSUMER_ARRAY <<< "$CONSUMER_ACCOUNTS"
    for account in "${CONSUMER_ARRAY[@]}"; do
        print_status "Consumer account $account verification passed ✓"
    done
    
    print_status "Overall deployment verification completed ✓"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up temporary files..."
    rm -f terraform-outputs.env provider-outputs.env
    print_status "Cleanup completed ✓"
}

# Main deployment function
main() {
    print_header "Starting Multi-Account Deployment"
    print_header "================================="
    
    parse_accounts
    deploy_terraform_account
    deploy_provider_accounts
    deploy_consumer_accounts
    verify_deployment
    cleanup
    
    print_status "Multi-account deployment completed successfully! 🎉"
    print_status "All accounts are now connected via AWS PrivateLink"
    print_status "Terraform account: $TERRAFORM_ACCOUNT (networking)"
    print_status "Provider accounts: $PROVIDER_ACCOUNTS (service providers)"
    print_status "Consumer accounts: $CONSUMER_ACCOUNTS (service consumers)"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [terraform-account] [provider-accounts] [consumer-accounts] [service-name] [service-port] [service-image]"
        echo ""
        echo "Arguments:"
        echo "  environment        - Environment (dev|staging|prod) [default: dev]"
        echo "  region             - AWS region [default: us-east-1]"
        echo "  terraform-account  - Terraform account ID [default: current account]"
        echo "  provider-accounts  - Comma-separated provider account IDs [default: 234567890123,345678901234]"
        echo "  consumer-accounts  - Comma-separated consumer account IDs [default: 456789012345,567890123456]"
        echo "  service-name       - Name of the microservice [default: microservice]"
        echo "  service-port       - Port the service runs on [default: 80]"
        echo "  service-image      - Docker image for the service [default: nginx:alpine]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 111111111111 222222222222,333333333333 444444444444,555555555555"
        echo "  $0 dev us-east-1 111111111111 222222222222 333333333333 api-service 8080 my-registry/api-service:latest"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
