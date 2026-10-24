# Configures the AWS provider.


provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "employee-management-app"
      ManagedBy = "Terraform"
    }
  }
}
