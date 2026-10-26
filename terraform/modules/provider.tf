# Configures the AWS provider from the shared region input.
# Keep provider-specific settings here rather than repeating them in resource files.


provider "aws" {
  region = var.aws_region
}
