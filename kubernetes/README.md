# Kubernetes deployment

The Kustomize overlays keep local development and EKS production separate:

- `overlays/development` uses images built into Docker Desktop's local image
  store (`backend:dev` and `frontend:dev`) and runs PostgreSQL in the cluster
  with a persistent volume claim.
- `overlays/production` pulls frontend and backend images from private ECR,
  connects to the production database through a secret-provided URL, and uses
  an AWS Application Load Balancer Ingress. PostgreSQL is not deployed in EKS.

## Docker Desktop development with k8 cluster - Local Kubernetes

Run these commands from the repository root. Docker Desktop Kubernetes must be
using the same local Docker image store.

Compose reads the root `.env` file even when only building images. Copy
`.env.example` to `.env` and set strong values for `POSTGRES_PASSWORD` and
`JWT_SECRET` before building. The Kubernetes deployment uses its own secret,
created in the next step.

```powershell
# Build the images Compose tags for the development Kubernetes overlay.
docker compose build --build-arg VITE_API_URL=http://localhost:8000/api backend frontend
```

Verify that kubectl is using the intended local cluster, then create the
development namespace:

```bash
kubectl config get-contexts
kubectl config current-context
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
```

Set strong `JWT_SECRET` and URL-safe `POSTGRES_PASSWORD` values in the root
`.env` file. Do not commit `.env`. From Git Bash at the repository root, create
or update the namespace's runtime secret from those values:

# The bash script below performs the following functions:
Enable strict bash execution 
load/validate env variables 
set default psql values 
create k8 secret
generate and apply k8 secret

```bash
(
  set -euo pipefail
  set -a
  source .env
  set +a

  : "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}"
  : "${JWT_SECRET:?Set JWT_SECRET in .env}"

  postgres_user="${POSTGRES_USER:-employee_app}"
  postgres_db="${POSTGRES_DB:-employee_management}"

  kubectl create secret generic application-secret \
    --namespace development \
    --from-literal=POSTGRES_USER="$postgres_user" \
    --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    --from-literal=POSTGRES_DB="$postgres_db" \
    --from-literal=DATABASE_URL="postgresql+psycopg://${postgres_user}:${POSTGRES_PASSWORD}@postgres-service:5432/${postgres_db}" \
    --from-literal=JWT_SECRET="$JWT_SECRET" \
    --dry-run=client -o yaml |
    kubectl apply -f -
)
```

The secret's `DATABASE_URL` points to the in-cluster `postgres-service`, not
`localhost` from the root `.env` (which is for a host-based backend). The
command requires `POSTGRES_PASSWORD` and `JWT_SECRET` and can be rerun to
update the secret. `kubectl` receives the values as command arguments, so avoid
running it on a shared machine. After creating the secret, apply or re-apply
the overlay:

```bash
kubectl apply -k ./kubernetes/overlays/development
```

The PostgreSQL claim uses the cluster's default storage class.

To open the app, run each port-forward in a separate terminal:

```powershell
Application is currently running on K8 cluster and not directly accessible.
Port forwarding is required to make the application accessible on local PC.
kubectl port-forward --namespace development service/frontend-service 5173:80
kubectl port-forward --namespace development service/backend-service 8000:8000
```

Browse to `http://localhost:5173`. The locally built frontend calls the
forwarded API at `http://localhost:8000/docs`.

Create a sign-in account in the development database:

```bash
kubectl exec -it -n development deployment/backend -- python create_user.py
```

## EKS production

Run these steps in order from the repository root in Git Bash. This is separate
from the Docker Desktop development path above. The base Terraform root creates
billable AWS resources, including EKS, NAT Gateway, and RDS; review its plan
before applying.

### 1. Provision the AWS foundation

Set `db_username` and `db_password` in the ignored
`terraform/modules/terraform.tfvars` file. Terraform state can contain
sensitive values; do not commit either file.

```bash
terraform -chdir=terraform/modules init
terraform -chdir=terraform/modules plan
# Review the plan before applying.
terraform -chdir=terraform/modules apply
```

This applies all `.tf` files in `terraform/modules` together. It also creates
the ECR repositories, GitHub OIDC role, External Secrets IAM role, and tags the
EKS subnets for load-balancer discovery. RDS ingress is restricted to the EKS
cluster security group.

### 2. Install EKS add-ons with Terraform

After the cluster is available, the separate Terraform root installs External
Secrets Operator and AWS Load Balancer Controller, including the controller's
IAM role and policy:

```bash
terraform -chdir=terraform/eks-addons init
terraform -chdir=terraform/eks-addons plan
# Review the plan before applying.
terraform -chdir=terraform/eks-addons apply
```

Secret values are intentionally not managed by Terraform.

### 3. Add production secrets

In AWS Secrets Manager in `us-east-1`, create:

- `production/postgres` with a `DATABASE_URL` property using the RDS endpoint
  from `terraform -chdir=terraform/modules output -raw rds_endpoint` and a
  URL-encoded database password.
- `production/application` with a strong `JWT_SECRET` property.

# Connect local kubectl configuration to an AWS EKS Kubernetes cluster named devops-cluster in the us-east-1 region.
```bash
aws eks update-kubeconfig --region us-east-1 --name devops-cluster
```

Do not put secret values in manifests, command history, or Terraform state.

### 4. Publish production images

The GitHub Actions workflow publishes images on successful pushes to `main`.
Ensure the repository secret `AWS_ROLE_ARN` points to the GitHub OIDC role in
the same AWS account as ECR, then push the desired commit:

```bash
git push origin main
```

Wait for the **Build and publish ECR images** job to succeed before applying
the production overlay. The workflow publishes both commit-SHA and `latest`
tags to the `frontend` and `backend` repositories in `us-east-1`.

### 5. Connect kubectl and deploy the application

Verify the AWS account, configure the EKS context, then apply the cluster-wide
secret store and application overlay:

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region us-east-1 --name devops-cluster
kubectl config current-context
kubectl get nodes
kubectl apply -f ./kubernetes/overlays/production/cluster-scoped/cluster-secret-store.yaml
kubectl wait --for=condition=Ready clustersecretstore/aws-secrets-manager --timeout=180s
kubectl apply -k ./kubernetes/overlays/production
kubectl wait --for=condition=Ready externalsecret/application-secret --namespace production --timeout=180s
kubectl rollout status deployment/backend --namespace production --timeout=300s
kubectl rollout status deployment/frontend --namespace production --timeout=300s
kubectl get pods,ingress --namespace production
```

The Kustomize overlay creates the `production` namespace. The Ingress currently
uses the controller's default internal scheme, so its ALB is reachable only
from the VPC or a connected network.

Create the initial application login if needed:

```bash
kubectl exec -it --namespace production deployment/backend -- python create_user.py
```

### 6. Deploy later image updates

After the ECR publishing workflow succeeds, restart the deployments to pull the
new `latest` images:

```bash
kubectl rollout restart deployment/backend deployment/frontend --namespace production
kubectl rollout status deployment/backend --namespace production
kubectl rollout status deployment/frontend --namespace production
```

For reproducible releases and rollbacks, change both `newTag` values in
`overlays/production/kustomization.yaml` to the same commit-SHA tag published
by CI, then apply the overlay. The image names and deployment tags must refer
to images that exist in the configured ECR repositories.