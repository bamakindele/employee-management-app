# Pins Terraform/provider compatibility so all resource files use a consistent AWS provider.
terraform {
  required_version = ">= 1.5.0"

  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }
}