# Creates the shared VPC network boundary; subnet resources are defined in subnets.tf.

resource "aws_vpc" "main" {

  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags,
    {
      Name = "main-vpc"
    }
  )
}