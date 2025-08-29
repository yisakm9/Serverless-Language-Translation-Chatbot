terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0" # Use a recent version of the AWS provider
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 0.60" # Use a recent version of the AWSCC provider
    }
  }
}

# --- Provider Configuration ---
provider "aws" {
  region = var.aws_region
}

provider "awscc" {
  region = var.aws_region
}

