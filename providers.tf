terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"


    default_tags {
        tags = {
        Project     = "self-healing-infra"
        ManagedBy   = "terraform"
        Environment = "portfolio"
        }
    }
}