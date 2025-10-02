#!/bin/bash

# Security Account Deployment Script
# This script deploys security services and monitoring

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
ORGANIZATION_ACCOUNTS=${4:-""}

print_header "Security Account Deployment"
print_header "=========================="
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "terraform-security-account" ]; then
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

# Parse organization accounts
parse_organization_accounts() {
    if [ -z "$ORGANIZATION_ACCOUNTS" ]; then
        print_warning "No organization accounts provided. Using defaults."
        # Default organization structure
        ROOT_ACCOUNT="123456789012"
        NETWORKING_ACCOUNT="111111111111"
        SHARED_SERVICES_ACCOUNT="999999999999"
        PROVIDER_ACCOUNTS="222222222222,333333333333"
        CONSUMER_ACCOUNTS="444444444444,555555555555"
    else
        # Parse the organization accounts string
        # Format: root:networking:shared-services:provider1,provider2:consumer1,consumer2
        IFS=':' read -ra ACCOUNTS <<< "$ORGANIZATION_ACCOUNTS"
        ROOT_ACCOUNT="${ACCOUNTS[0]}"
        NETWORKING_ACCOUNT="${ACCOUNTS[1]}"
        SHARED_SERVICES_ACCOUNT="${ACCOUNTS[2]}"
        PROVIDER_ACCOUNTS="${ACCOUNTS[3]}"
        CONSUMER_ACCOUNTS="${ACCOUNTS[4]}"
    fi
    
    print_status "Root Account: $ROOT_ACCOUNT"
    print_status "Networking Account: $NETWORKING_ACCOUNT"
    print_status "Shared Services Account: $SHARED_SERVICES_ACCOUNT"
    print_status "Provider Accounts: $PROVIDER_ACCOUNTS"
    print_status "Consumer Accounts: $CONSUMER_ACCOUNTS"
}

# Deploy Security infrastructure
deploy_security() {
    print_header "Deploying Security Infrastructure"
    
    cd terraform-security-account
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
aws_region = "$REGION"
account_id = "$ACCOUNT_ID"
environment = "$ENVIRONMENT"

organization_accounts = {
  root_account_id         = "$ROOT_ACCOUNT"
  networking_account_id   = "$NETWORKING_ACCOUNT"
  shared_services_account_id = "$SHARED_SERVICES_ACCOUNT"
  provider_account_ids    = [$(echo $PROVIDER_ACCOUNTS | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//' | tr '\n' ' ')]
  consumer_account_ids    = [$(echo $CONSUMER_ACCOUNTS | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//' | tr '\n' ' ')]
}

cloudtrail_s3_bucket_name = "organization-cloudtrail-${ENVIRONMENT}-${ACCOUNT_ID}"
config_s3_bucket_name = "organization-config-${ENVIRONMENT}-${ACCOUNT_ID}"

security_hub_standards = [
  "aws-foundational-security-standard",
  "cis-aws-foundations-benchmark"
]

guardduty_finding_publishing_frequency = "FIFTEEN_MINUTES"
inspector_assessment_duration = 3600
cross_account_external_id = "security-${ENVIRONMENT}-$(date +%s)"
EOF
    
    # Initialize Terraform
    terraform init
    
    # Plan and apply
    print_status "Planning Security deployment..."
    terraform plan -var-file="terraform.tfvars"
    
    print_status "Applying Security configuration..."
    terraform apply -var-file="terraform.tfvars" -auto-approve
    
    # Export outputs
    export SECURITY_AUDIT_ROLE_ARN=$(terraform output -raw security_audit_role_arn)
    export SECURITY_ALERTS_TOPIC_ARN=$(terraform output -raw security_alerts_topic_arn)
    export CLOUDTRAIL_ARN=$(terraform output -raw cloudtrail_arn)
    export GUARDDUTY_DETECTOR_ID=$(terraform output -raw guardduty_detector_id)
    
    print_status "Security deployment completed ✓"
    print_status "Security Audit Role ARN: $SECURITY_AUDIT_ROLE_ARN"
    print_status "Security Alerts Topic ARN: $SECURITY_ALERTS_TOPIC_ARN"
    
    # Save outputs to file for other scripts
    cat > ../security-outputs.env << EOF
export SECURITY_AUDIT_ROLE_ARN="$SECURITY_AUDIT_ROLE_ARN"
export SECURITY_ALERTS_TOPIC_ARN="$SECURITY_ALERTS_TOPIC_ARN"
export CLOUDTRAIL_ARN="$CLOUDTRAIL_ARN"
export GUARDDUTY_DETECTOR_ID="$GUARDDUTY_DETECTOR_ID"
EOF
    
    cd ..
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Security Deployment"
    
    cd terraform-security-account
    
    # Check CloudTrail
    aws cloudtrail describe-trails --region $REGION > /dev/null
    print_status "CloudTrail verification passed ✓"
    
    # Check GuardDuty
    aws guardduty list-detectors --region $REGION > /dev/null
    print_status "GuardDuty verification passed ✓"
    
    # Check Security Hub
    aws securityhub describe-hub --region $REGION > /dev/null
    print_status "Security Hub verification passed ✓"
    
    # Check Config
    aws configservice describe-configuration-recorders --region $REGION > /dev/null
    print_status "AWS Config verification passed ✓"
    
    cd ..
}

# Main deployment function
main() {
    print_header "Starting Security Account Deployment"
    print_header "==================================="
    
    check_prerequisites
    get_account_id
    parse_organization_accounts
    deploy_security
    verify_deployment
    
    print_status "Security account deployment completed successfully! 🎉"
    print_status "Security services are now monitoring the organization"
    print_status "Outputs saved to security-outputs.env for use by other scripts"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [account-id] [organization-accounts]"
        echo ""
        echo "Arguments:"
        echo "  environment           - Environment (dev|staging|prod) [default: dev]"
        echo "  region               - AWS region [default: us-east-1]"
        echo "  account-id           - AWS account ID [default: current account]"
        echo "  organization-accounts - Colon-separated account structure [default: defaults]"
        echo "                         Format: root:networking:shared-services:provider1,provider2:consumer1,consumer2"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 888888888888        # Deploy to prod with specific account"
        echo "  $0 dev us-east-1 888888888888 123456789012:111111111111:999999999999:222222222222,333333333333:444444444444,555555555555"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
