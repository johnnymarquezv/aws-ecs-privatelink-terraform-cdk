terraform {
  required_version = ">= 1.13"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # Using local backend for testing purposes
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "shared-services-account/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-lock-table"
  #   encrypt        = true
  # }
}

provider "aws" {
  region  = local.aws_region
  profile = "shared-services-account"  # Hardcoded profile for shared services account
  
  default_tags {
    tags = {
      Project     = "Multi-Account-Microservices"
      Environment = local.environment
      ManagedBy   = "Terraform"
      AccountType = "shared-services"
    }
  }
}
