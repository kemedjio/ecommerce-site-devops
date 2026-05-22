terraform {
  backend "s3" {
    bucket = "ecommerce-terraform-backend-bucket234"
    key = "s3-backend"
    region = "us-east-1"
    
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.38.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

