# environments/dev/versions.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # This is the only provider we need
    }
  }
}
