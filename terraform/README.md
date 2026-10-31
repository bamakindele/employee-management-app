# Terraform infrastructure

This directory contains the Terraform configuration for the employee-management application’s AWS infrastructure. The configuration provisions a VPC, public and private networking, an EKS cluster and worker nodes, ECR repositories, and a private PostgreSQL RDS instance.

## Directory layout

```text
terraform/
├── architecture_doc/   Architecture diagrams
├── screenshots/        Screenshots of the deployed AWS resources and Terraform output
├── modules/            Terraform working directory and infrastructure configuration
└── README.md
```

`modules/` is currently the **root Terraform configuration directory**: run Terraform commands from there. It is not a collection of separate Terraform child modules yet; all `.tf` files in that directory are evaluated together as one configuration. The `modules/data/` directory is currently empty.

## Configuration files

The `.tf` files are grouped by infrastructure concern:

| File | Purpose |
| --- | --- |
| `versions.tf` | Terraform and AWS provider version constraints |
| `provider.tf` | AWS provider configuration |
| `variables.tf` | Configurable project, region, network, and database inputs |
| `locals.tf` | Shared tags used by resources |
| `vpc.tf`, `subnets.tf` | VPC and public/private subnets |
| `internet_gateway.tf`, `nat_gateway.tf`, `route_tables.tf` | Internet access and subnet routing |
| `security_groups.tf` | EKS node and RDS network rules |
| `iam_eks_cluster_role.tf`, `iam_node_group_role.tf` | IAM roles and policies for EKS |
| `eks_cluster.tf`, `eks_node_group.tf` | EKS control plane and managed worker nodes |
| `ecr.tf` | Frontend and backend container image repositories |
| `rds_subnet_group.tf`, `rds.tf` | Private database subnet group and PostgreSQL instance |
| `outputs.tf` | Useful resource identifiers and endpoints |

The `.terraform.lock.hcl` file records the selected provider versions. Keep it under version control so runs resolve consistent provider versions.

## Prerequisites

- Terraform `>= 1.5.0`
- AWS CLI credentials configured for an account with permission to manage the resources in this configuration
- An AWS region supported by the configuration

The AWS provider region defaults to `us-east-1`. The subnet CIDRs and availability zones are currently hard-coded in `subnets.tf` to `us-east-1a` and `us-east-1b`; update those values together with the region before deploying elsewhere.

## Inputs and secrets

`aws_region`, `project_name`, and `vpc_cidr` have defaults in `variables.tf`. `db_username` and `db_password` must be supplied.

Do not commit credentials or real passwords. The repository `.gitignore` excludes `*.tfvars`, including `terraform.tfvars`. For local development, supply values in an ignored `terraform.tfvars` file, or use environment variables such as `TF_VAR_db_username` and `TF_VAR_db_password`. For shared or production deployments, retrieve secrets from an approved secret manager and avoid storing them in plaintext files or shell history.

Terraform state can contain sensitive values. This configuration currently uses Terraform's default local backend; protect the state file and its backups, do not commit them, and configure an encrypted remote backend with state locking before team or production use.

## Initialize, validate, and deploy

Run these commands from the repository root:

```sh
terraform -chdir=terraform/modules init
terraform -chdir=terraform/modules fmt -check
terraform -chdir=terraform/modules validate
terraform -chdir=terraform/modules plan
terraform -chdir=terraform/modules apply
```

Review the plan before applying. These resources can incur AWS charges, especially EKS, the NAT Gateway, and RDS. When the infrastructure is no longer needed, review the resources and dependencies before running:

```sh
terraform -chdir=terraform/modules destroy
```

## Reuse and maintenance

The `.tf` files include short descriptions of each file's responsibility. Shared values belong in input variables or `locals` rather than being repeated across resource blocks. To make this configuration reusable for other environments, parameterize the currently fixed subnet CIDRs, availability zones, names, and scaling settings; then consider extracting cohesive components into actual child modules with explicit inputs and outputs.
