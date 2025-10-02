#!/bin/bash

# Shared Services Account Deployment Script
# This script deploys CI/CD, monitoring, and shared services

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
GITHUB_REPO_URL=${5:-""}

print_header "Shared Services Account Deployment"
print_header "=================================="
print_status "Environment: $ENVIRONMENT"
print_status "Region: $REGION"
print_status "GitHub Repo: $GITHUB_REPO_URL"

# Check if we're in the right directory
if [ ! -f "README.md" ] || [ ! -d "terraform-shared-services-account" ]; then
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
        SECURITY_ACCOUNT="888888888888"
        NETWORKING_ACCOUNT="111111111111"
        PROVIDER_ACCOUNTS="222222222222,333333333333"
        CONSUMER_ACCOUNTS="444444444444,555555555555"
    else
        # Parse the organization accounts string
        # Format: root:security:networking:provider1,provider2:consumer1,consumer2
        IFS=':' read -ra ACCOUNTS <<< "$ORGANIZATION_ACCOUNTS"
        ROOT_ACCOUNT="${ACCOUNTS[0]}"
        SECURITY_ACCOUNT="${ACCOUNTS[1]}"
        NETWORKING_ACCOUNT="${ACCOUNTS[2]}"
        PROVIDER_ACCOUNTS="${ACCOUNTS[3]}"
        CONSUMER_ACCOUNTS="${ACCOUNTS[4]}"
    fi
    
    print_status "Root Account: $ROOT_ACCOUNT"
    print_status "Security Account: $SECURITY_ACCOUNT"
    print_status "Networking Account: $NETWORKING_ACCOUNT"
    print_status "Provider Accounts: $PROVIDER_ACCOUNTS"
    print_status "Consumer Accounts: $CONSUMER_ACCOUNTS"
}

# Deploy Shared Services infrastructure
deploy_shared_services() {
    print_header "Deploying Shared Services Infrastructure"
    
    cd terraform-shared-services-account
    
    # Create terraform.tfvars
    cat > terraform.tfvars << EOF
aws_region = "$REGION"
account_id = "$ACCOUNT_ID"
environment = "$ENVIRONMENT"

organization_accounts = {
  root_account_id         = "$ROOT_ACCOUNT"
  security_account_id     = "$SECURITY_ACCOUNT"
  networking_account_id   = "$NETWORKING_ACCOUNT"
  provider_account_ids    = [$(echo $PROVIDER_ACCOUNTS | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//' | tr '\n' ' ')]
  consumer_account_ids    = [$(echo $CONSUMER_ACCOUNTS | tr ',' '\n' | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//' | tr '\n' ' ')]
}

artifacts_s3_bucket_name = "shared-services-artifacts-${ENVIRONMENT}-${ACCOUNT_ID}"
container_registry_name = "microservice"
codebuild_compute_type = "BUILD_GENERAL1_MEDIUM"

github_repo_url = "$GITHUB_REPO_URL"
github_token_secret_name = "github-token-${ENVIRONMENT}"

cross_account_external_id = "shared-services-${ENVIRONMENT}-$(date +%s)"
monitoring_retention_days = 30
enable_xray = true
prometheus_workspace_alias = "microservices-monitoring-${ENVIRONMENT}"
EOF
    
    # Initialize Terraform
    terraform init
    
    # Plan and apply
    print_status "Planning Shared Services deployment..."
    terraform plan -var-file="terraform.tfvars"
    
    print_status "Applying Shared Services configuration..."
    terraform apply -var-file="terraform.tfvars" -auto-approve
    
    # Export outputs
    export ECR_REPOSITORY_URL=$(terraform output -raw ecr_repository_url)
    export CODEBUILD_PROJECT_NAME=$(terraform output -raw codebuild_project_name)
    export MONITORING_ROLE_ARN=$(terraform output -raw monitoring_role_arn)
    export PROMETHEUS_WORKSPACE_ID=$(terraform output -raw prometheus_workspace_id)
    export PROMETHEUS_ENDPOINT=$(terraform output -raw prometheus_endpoint)
    export ARTIFACTS_S3_BUCKET=$(terraform output -raw artifacts_s3_bucket)
    
    print_status "Shared Services deployment completed ✓"
    print_status "ECR Repository URL: $ECR_REPOSITORY_URL"
    print_status "CodeBuild Project: $CODEBUILD_PROJECT_NAME"
    print_status "Prometheus Workspace: $PROMETHEUS_WORKSPACE_ID"
    
    # Save outputs to file for other scripts
    cat > ../shared-services-outputs.env << EOF
export ECR_REPOSITORY_URL="$ECR_REPOSITORY_URL"
export CODEBUILD_PROJECT_NAME="$CODEBUILD_PROJECT_NAME"
export MONITORING_ROLE_ARN="$MONITORING_ROLE_ARN"
export PROMETHEUS_WORKSPACE_ID="$PROMETHEUS_WORKSPACE_ID"
export PROMETHEUS_ENDPOINT="$PROMETHEUS_ENDPOINT"
export ARTIFACTS_S3_BUCKET="$ARTIFACTS_S3_BUCKET"
EOF
    
    cd ..
}

# Create buildspec for CodeBuild
create_buildspec() {
    print_header "Creating CodeBuild Buildspec"
    
    cat > buildspec.yml << EOF
version: 0.2

phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region \$AWS_DEFAULT_REGION | docker login --username AWS --password-stdin \$AWS_ACCOUNT_ID.dkr.ecr.\$AWS_DEFAULT_REGION.amazonaws.com
      - REPOSITORY_URI=\$AWS_ACCOUNT_ID.dkr.ecr.\$AWS_DEFAULT_REGION.amazonaws.com/\$IMAGE_REPO_NAME
      - COMMIT_HASH=\$(echo \$CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - IMAGE_TAG=\${COMMIT_HASH:=\$IMAGE_TAG}
  build:
    commands:
      - echo Build started on \`date\`
      - echo Building the Docker image...
      - cd microservice-repo
      - docker build -t \$IMAGE_REPO_NAME:latest .
      - docker tag \$IMAGE_REPO_NAME:latest \$REPOSITORY_URI:latest
      - docker tag \$IMAGE_REPO_NAME:latest \$REPOSITORY_URI:\$IMAGE_TAG
      - docker tag \$IMAGE_REPO_NAME:latest \$REPOSITORY_URI:\$ENVIRONMENT-\$IMAGE_TAG
  post_build:
    commands:
      - echo Build completed on \`date\`
      - echo Pushing the Docker images...
      - docker push \$REPOSITORY_URI:latest
      - docker push \$REPOSITORY_URI:\$IMAGE_TAG
      - docker push \$REPOSITORY_URI:\$ENVIRONMENT-\$IMAGE_TAG
      - echo Writing image definitions file...
      - printf '[{"name":"%s","imageUri":"%s"}]' \$IMAGE_REPO_NAME \$REPOSITORY_URI:\$IMAGE_TAG > imagedefinitions.json

artifacts:
  files:
    - imagedefinitions.json
    - '**/*'
  name: microservice-build-\$(date +%Y-%m-%d)
EOF
    
    print_status "Buildspec created ✓"
}

# Verify deployment
verify_deployment() {
    print_header "Verifying Shared Services Deployment"
    
    cd terraform-shared-services-account
    
    # Check ECR repository
    aws ecr describe-repositories --repository-names microservice --region $REGION > /dev/null
    print_status "ECR repository verification passed ✓"
    
    # Check CodeBuild project
    aws codebuild batch-get-projects --names $CODEBUILD_PROJECT_NAME --region $REGION > /dev/null
    print_status "CodeBuild project verification passed ✓"
    
    # Check S3 bucket
    aws s3api head-bucket --bucket $ARTIFACTS_S3_BUCKET --region $REGION
    print_status "S3 artifacts bucket verification passed ✓"
    
    # Check Prometheus workspace
    aws amp describe-workspace --workspace-id $PROMETHEUS_WORKSPACE_ID --region $REGION > /dev/null
    print_status "Prometheus workspace verification passed ✓"
    
    cd ..
}

# Setup GitHub integration
setup_github_integration() {
    if [ ! -z "$GITHUB_REPO_URL" ]; then
        print_header "Setting up GitHub Integration"
        
        print_warning "To complete GitHub integration:"
        print_warning "1. Store your GitHub personal access token in AWS Secrets Manager:"
        print_warning "   aws secretsmanager put-secret-value --secret-id github-token-${ENVIRONMENT} --secret-string 'your-github-token'"
        print_warning "2. Configure GitHub webhook to trigger CodeBuild on push events"
        print_warning "3. Update your GitHub repository with the buildspec.yml file"
        
        print_status "GitHub integration setup instructions provided ✓"
    fi
}

# Main deployment function
main() {
    print_header "Starting Shared Services Account Deployment"
    print_header "=========================================="
    
    check_prerequisites
    get_account_id
    parse_organization_accounts
    deploy_shared_services
    create_buildspec
    verify_deployment
    setup_github_integration
    
    print_status "Shared Services account deployment completed successfully! 🎉"
    print_status "CI/CD and monitoring services are now available"
    print_status "Outputs saved to shared-services-outputs.env for use by other scripts"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [environment] [region] [account-id] [organization-accounts] [github-repo-url]"
        echo ""
        echo "Arguments:"
        echo "  environment           - Environment (dev|staging|prod) [default: dev]"
        echo "  region               - AWS region [default: us-east-1]"
        echo "  account-id           - AWS account ID [default: current account]"
        echo "  organization-accounts - Colon-separated account structure [default: defaults]"
        echo "                         Format: root:security:networking:provider1,provider2:consumer1,consumer2"
        echo "  github-repo-url      - GitHub repository URL [optional]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Deploy with defaults"
        echo "  $0 dev us-west-2                      # Deploy to dev environment in us-west-2"
        echo "  $0 prod us-east-1 999999999999        # Deploy to prod with specific account"
        echo "  $0 dev us-east-1 999999999999 123456789012:888888888888:111111111111:222222222222,333333333333:444444444444,555555555555 https://github.com/your-org/microservice"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
