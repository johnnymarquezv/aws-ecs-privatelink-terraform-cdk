variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "isolated_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.5.0/28", "10.0.6.0/28"]
}

# Multi-account configuration
variable "account_id" {
  description = "Current AWS account ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "microservices_accounts" {
  description = "List of microservices account IDs"
  type        = list(string)
  default     = []
}

variable "cross_account_external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  sensitive   = true
}
