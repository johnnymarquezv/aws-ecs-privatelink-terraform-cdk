#!/bin/bash

# Microservice Build and Push Script
# This script builds and pushes the microservice to a container registry

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
REGISTRY=${1:-"ghcr.io"}
IMAGE_NAME=${2:-"microservice"}
TAG=${3:-"latest"}
VERSION=${4:-"1.0.0"}

print_header "Microservice Build and Push"
print_header "==========================="
print_status "Registry: $REGISTRY"
print_status "Image: $IMAGE_NAME"
print_status "Tag: $TAG"
print_status "Version: $VERSION"

# Check if we're in the right directory
if [ ! -f "microservice-repo/Dockerfile" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI"
        exit 1
    fi
    
    print_status "All prerequisites are installed ✓"
}

# Login to registry
login_to_registry() {
    print_status "Logging in to registry..."
    
    if [ "$REGISTRY" = "ghcr.io" ]; then
        # GitHub Container Registry
        echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin
    elif [ "$REGISTRY" = "public.ecr.aws" ]; then
        # AWS ECR Public
        aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws
    elif [[ "$REGISTRY" == *".amazonaws.com" ]]; then
        # AWS ECR Private
        aws ecr get-login-password --region ${AWS_DEFAULT_REGION:-us-east-1} | docker login --username AWS --password-stdin $REGISTRY
    else
        print_warning "Unknown registry type. Please ensure you're logged in manually."
    fi
    
    print_status "Registry login completed ✓"
}

# Build the image
build_image() {
    print_header "Building Microservice Image"
    
    cd microservice-repo
    
    # Build the image
    print_status "Building Docker image..."
    docker build -t $REGISTRY/$IMAGE_NAME:$TAG .
    docker build -t $REGISTRY/$IMAGE_NAME:$VERSION .
    
    print_status "Image built successfully ✓"
    
    cd ..
}

# Test the image
test_image() {
    print_header "Testing Microservice Image"
    
    print_status "Running container test..."
    
    # Run the container in the background
    CONTAINER_ID=$(docker run -d -p 8000:8000 \
        -e SERVICE_NAME=test-service \
        -e CONSUMER_SERVICES='[{"name":"test-service","endpoint":"localhost","port":8080}]' \
        $REGISTRY/$IMAGE_NAME:$TAG)
    
    # Wait for the service to start
    sleep 10
    
    # Test health endpoint
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        print_status "Health check passed ✓"
    else
        print_error "Health check failed"
        docker logs $CONTAINER_ID
        docker stop $CONTAINER_ID
        exit 1
    fi
    
    # Test root endpoint
    if curl -f http://localhost:8000/ > /dev/null 2>&1; then
        print_status "Root endpoint test passed ✓"
    else
        print_error "Root endpoint test failed"
        docker logs $CONTAINER_ID
        docker stop $CONTAINER_ID
        exit 1
    fi
    
    # Stop the container
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID
    
    print_status "Image testing completed ✓"
}

# Push the image
push_image() {
    print_header "Pushing Microservice Image"
    
    print_status "Pushing image to registry..."
    docker push $REGISTRY/$IMAGE_NAME:$TAG
    docker push $REGISTRY/$IMAGE_NAME:$VERSION
    
    print_status "Image pushed successfully ✓"
}

# Create ECR repository if it doesn't exist
create_ecr_repository() {
    if [[ "$REGISTRY" == *".amazonaws.com" ]]; then
        print_status "Creating ECR repository if it doesn't exist..."
        
        REPO_NAME=$(echo $REGISTRY | cut -d'/' -f2)
        REGION=$(echo $REGISTRY | cut -d'.' -f4)
        
        aws ecr describe-repositories --repository-names $REPO_NAME --region $REGION > /dev/null 2>&1 || {
            print_status "Creating ECR repository: $REPO_NAME"
            aws ecr create-repository --repository-name $REPO_NAME --region $REGION
        }
        
        print_status "ECR repository ready ✓"
    fi
}

# Main build function
main() {
    print_header "Starting Microservice Build Process"
    print_header "==================================="
    
    check_prerequisites
    create_ecr_repository
    login_to_registry
    build_image
    test_image
    push_image
    
    print_status "Microservice build and push completed successfully! 🎉"
    print_status "Image: $REGISTRY/$IMAGE_NAME:$TAG"
    print_status "Image: $REGISTRY/$IMAGE_NAME:$VERSION"
}

# Handle script arguments
case "${1:-}" in
    "help"|"-h"|"--help")
        echo "Usage: $0 [registry] [image-name] [tag] [version]"
        echo ""
        echo "Arguments:"
        echo "  registry     - Container registry URL [default: ghcr.io]"
        echo "  image-name   - Image name [default: microservice]"
        echo "  tag          - Image tag [default: latest]"
        echo "  version      - Version tag [default: 1.0.0]"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Build with defaults"
        echo "  $0 ghcr.io my-org/microservice v1.0.0 1.0.0"
        echo "  $0 123456789012.dkr.ecr.us-east-1.amazonaws.com my-microservice latest 1.0.0"
        ;;
    "")
        main
        ;;
    *)
        main
        ;;
esac
