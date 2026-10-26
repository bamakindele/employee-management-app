# Input variables for the Terraform root configuration.
# Add descriptions, types, and validation when introducing reusable inputs.

variable "aws_region" {
  default = "us-east-1"
}

variable "project_name" {
  default = "devops-platform"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_username" {}

variable "db_password" {
  sensitive = true
}