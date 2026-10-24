# Variables for the Terraform module and values.

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "learning-eks"
}

variable "cluster_version" {
  description = "Supported EKS Kubernetes version"
  type        = string
  default     = "1.34"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "cluster_admin_cidr" {
  description = "Your public IPv4 address in CIDR notation"
  type        = string

  validation {
    condition     = can(cidrhost(var.cluster_admin_cidr, 0)) && can(regex("/32$", var.cluster_admin_cidr))
    error_message = "Use your public IPv4 address followed by /32."
  }
}

variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "appdb"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
