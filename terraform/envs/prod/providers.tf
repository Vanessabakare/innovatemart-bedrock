terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}  # values come from backend.hcl
}

variable "aws_region"  { default = "us-east-1" }

provider "aws" {
  region = var.aws_region


  default_tags {
    tags = {
      innovate    = "true"
      ManagedBy   = "terraform"
      Environment = "prod"
    }
  }
}

data "aws_caller_identity" "current" {}
