terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {}  # values supplied via backend.hcl at init
}

variable "aws_region"  { default = "us-east-1" }
variable "aws_profile" { default = "InnovateMart" }

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  # Auto-tag every resource we create
  default_tags {
    tags = {
      innovate    = "true"
      ManagedBy   = "terraform"
      Environment = "prod"
    }
  }
}

# simple sanity data source
data "aws_caller_identity" "current" {}
