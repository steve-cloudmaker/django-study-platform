terraform {
  required_version = ">= 1.5.0"

  # Optional remote state (bootstrap bucket + DynamoDB lock table first):
  # backend "s3" {
  #   bucket         = "YOUR_TF_STATE_BUCKET"
  #   key            = "study-platform/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "YOUR_TF_LOCK_TABLE"
  #   encrypt        = true
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.89"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
