# environments/dev/versions.tf

terraform {
  required_providers {
    # Standard provider for IAM, Lambda, etc.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Cloud Control provider for modern services like Lex V2
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 0.60" # Use a recent version
    }
  }
}
