# Centralizes tags so supported resources can share consistent project metadata.
locals {

  tags = {
    Project     = var.project_name
    Environment = "dev"
    ManagedBy   = "Terraform"
  }

}