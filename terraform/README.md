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
| `iam_oidc_github_ecr_role.tf` | GitHub Actions OIDC provider, deployment role, and scoped ECR push policy |
| `eks_cluster.tf`, `eks_node_group.tf` | EKS control plane and managed worker nodes |
| `ecr.tf` | Frontend and backend container image repositories |
| `rds_subnet_group.tf`, `rds.tf` | Private database subnet group and PostgreSQL instance |
| `outputs.tf` | Useful resource identifiers and endpoints |

The `.terraform.lock.hcl` file records the selected provider versions. Keep it under version control so runs resolve consistent provider versions.

## Prerequisites

- Terraform `>= 1.5.0`
- AWS CLI credentials configured for an account with permission to manage the resources in this configuration
- GitHub repository administrator access to add the `AWS_ROLE_ARN` Actions secret
- An AWS region supported by the configuration

The AWS provider region defaults to `us-east-1`. The subnet CIDRs and availability zones are currently hard-coded in `subnets.tf` to `us-east-1a` and `us-east-1b`; update those values together with the region before deploying elsewhere.

## Inputs and secrets

`aws_region`, `project_name`, and `vpc_cidr` have defaults in `variables.tf`. `db_username` and `db_password` must be supplied.

Do not commit credentials or real passwords. The repository `.gitignore` excludes `*.tfvars`, including `terraform.tfvars`. For local development, supply values in an ignored `terraform.tfvars` file, or use environment variables such as `TF_VAR_db_username` and `TF_VAR_db_password`. For shared or production deployments, retrieve secrets from an approved secret manager and avoid storing them in plaintext files or shell history.

Terraform state can contain sensitive values. This configuration currently uses Terraform's default local backend; protect the state file and its backups, do not commit them, and configure an encrypted remote backend with state locking before team or production use.

## GitHub Actions OIDC and ECR publishing

The root `.github/workflows/ci.yml` workflow runs application checks on pull
requests and pushes to `main`. Only a push to `main` that passes those checks
runs the **Build and publish ECR images** job. It builds and scans the frontend
and backend images, then pushes both the commit-SHA and `latest` tags to the
`frontend` and `backend` ECR repositories in `us-east-1`. Trivy findings are
currently informational and do not block publishing.

The OIDC trust policy in `modules/iam_oidc_github_ecr_role.tf` restricts role
assumption to `bamakindele/employee-management-app` on `main`; its inline
permissions allow image pushes only to the two application repositories. The
workflow uses short-lived OIDC credentials and requires a GitHub repository
Actions secret named `AWS_ROLE_ARN`, whose value is the IAM role ARN. Add or
update that secret in **GitHub repository Settings → Secrets and variables →
Actions**. Do not store long-lived AWS access keys in GitHub.

The ECR repositories (`frontend` and `backend`) are defined in
`modules/ecr.tf`. Ensure both
repositories and the OIDC role are provisioned in the same AWS account and
region used by the workflow.

To review and apply only the GitHub OIDC role and its ECR permissions, run from
the repository root:

```powershell
terraform -chdir=terraform/modules plan `
  -target=aws_iam_role.github_actions_ecr `
  -target=aws_iam_role_policy.github_actions_ecr

# Review the plan before applying.
terraform -chdir=terraform/modules apply `
  -target=aws_iam_role.github_actions_ecr `
  -target=aws_iam_role_policy.github_actions_ecr
```

Terraform includes the OIDC provider as a dependency when needed. Targeted
operations are intended only for this focused setup; review the plan carefully
and run a regular plan afterward to check for other pending infrastructure
changes.

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
