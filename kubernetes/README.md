# Kubernetes deployment

The Kustomize overlays keep local development and EKS production separate:

- `overlays/development` uses images built into Docker Desktop's local image
  store (`backend:dev` and `frontend:dev`) and runs PostgreSQL in the cluster
  with a persistent volume claim.
- `overlays/production` pulls frontend and backend images from private ECR,
  connects to the production database through a secret-provided URL, and uses
  an AWS Application Load Balancer Ingress. PostgreSQL is not deployed in EKS.

## Docker Desktop development

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
forwarded API at `http://localhost:8000/api`.

Create a sign-in account in the development database:

```bash
kubectl exec -it -n development deployment/backend -- python create_user.py
```

## EKS production

Run these commands sequentially in the same Git Bash session from the
repository root; later commands use shell variables set earlier. You also need
an AWS identity with permissions to provision the Terraform resources, create
IAM roles and policies, push to ECR, and deploy to EKS. This Terraform
configuration creates billable AWS resources. Review every Terraform plan
before applying it.

The production overlay uses the `frontend` and `backend` ECR repositories in
`us-east-1`. Its images are separate from the local Compose `*:dev` images.

### 1. Provision AWS infrastructure

Create `terraform/modules/terraform.tfvars` with values for the required
`db_username` and `db_password` inputs. Keep it out of source control; Terraform
state also contains sensitive data. See [terraform/README.md](../terraform/README.md)
for state and credential guidance.

Run Terraform from the repository root:

```bash
terraform -chdir=terraform/modules init
terraform -chdir=terraform/modules plan
# Review the plan before applying; EKS, NAT Gateway, and RDS incur charges.
terraform -chdir=terraform/modules apply
```

Configure kubectl for the Terraform-created EKS cluster and verify the active
AWS account and Kubernetes context before proceeding:

```bash
AWS_REGION=us-east-1
CLUSTER_NAME=$(terraform -chdir=terraform/modules output -raw cluster_name)
VPC_ID=$(terraform -chdir=terraform/modules output -raw vpc_id)
aws sts get-caller-identity
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl config current-context
kubectl get nodes
```

The account returned by `aws sts get-caller-identity` must match the account
in the production ECR image names in
`overlays/production/kustomization.yaml`.

### 2. Tag VPC subnets for load-balancer discovery

The AWS Load Balancer Controller uses subnet tags to discover where to create
an ALB. The Terraform subnet resources currently do not set these tags. Tag the
public and private subnets created by this configuration:

```bash
get_subnet_id() {
  aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=$1" \
    --query 'Subnets[0].SubnetId' --output text
}

PUBLIC_A=$(get_subnet_id 10.0.1.0/24)
PUBLIC_B=$(get_subnet_id 10.0.2.0/24)
PRIVATE_A=$(get_subnet_id 10.0.11.0/24)
PRIVATE_B=$(get_subnet_id 10.0.12.0/24)

aws ec2 create-tags --resources "$PUBLIC_A" "$PUBLIC_B" \
  --tags "Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared" \
         "Key=kubernetes.io/role/elb,Value=1"
aws ec2 create-tags --resources "$PRIVATE_A" "$PRIVATE_B" \
  --tags "Key=kubernetes.io/cluster/$CLUSTER_NAME,Value=shared" \
         "Key=kubernetes.io/role/internal-elb,Value=1"
```

These are AWS-side tags not currently managed by Terraform; reapply them if
the subnets are recreated, or add equivalent `tags` to the Terraform subnet
resources.

The production Ingress currently has no scheme annotation. The AWS Load
Balancer Controller therefore uses its default `internal` scheme, selecting
private subnets; the ALB is reachable only from networks connected to the VPC.
For an internet-facing ALB, add
`alb.ingress.kubernetes.io/scheme: internet-facing` under `metadata.annotations`
in `overlays/production/ingress.yaml` before applying the overlay. It will use
the tagged public subnets. Do not make the ALB internet-facing unless that is
the intended exposure.

### 3. Publish production images to ECR

The GitHub Actions workflow builds the production frontend with
`VITE_API_URL=/api`, then pushes both commit-SHA and `latest` tags to ECR.
After committing the desired changes, push to `main` and wait for the
**Build and publish ECR images** job to succeed:

```bash
git push origin main
```

The workflow requires the `AWS_ROLE_ARN` GitHub Actions secret and the
`frontend` and `backend` ECR repositories provisioned by Terraform. Verify the
published `latest` tags before deploying:

```bash
aws ecr describe-images --region "$AWS_REGION" \
  --repository-name frontend --image-ids imageTag=latest
aws ecr describe-images --region "$AWS_REGION" \
  --repository-name backend --image-ids imageTag=latest
```

Do not push the Compose development images to production: their frontend is
built with a localhost API URL. For manual publishing, use the production
build arguments and ECR procedure in the root [README](../README.md#ci-and-publishing-images-to-amazon-ecr).

### 4. Install External Secrets Operator and configure IRSA

Install the operator and its CRDs with Helm:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace external-secrets --create-namespace --wait
kubectl rollout status deployment/external-secrets \
  --namespace external-secrets --timeout=180s
```

The full Terraform apply creates the EKS OIDC provider and the
`external-secrets` IAM role. Annotate the operator ServiceAccount with that
role and restart the controller so its pod receives IRSA credentials:

```bash
ROLE_ARN=$(terraform -chdir=terraform/modules output -raw external_secrets_role_arn)
kubectl annotate serviceaccount external-secrets \
  --namespace external-secrets \
  eks.amazonaws.com/role-arn="$ROLE_ARN" --overwrite
kubectl rollout restart deployment/external-secrets \
  --namespace external-secrets
kubectl rollout status deployment/external-secrets \
  --namespace external-secrets --timeout=180s
```

If the role output is missing, apply the External Secrets role resources as
described in [terraform/README.md](../terraform/README.md#external-secrets-operator-irsa).
The role trust is limited to this ServiceAccount and its policy permits reads
only from `production/postgres` and `production/application`.

### 5. Install AWS Load Balancer Controller

Install `eksctl` and Helm first. The EKS OIDC provider created by Terraform is
also used for this controller's IAM role. The following example uses the
upstream controller release `v3.6.3`; check the
[AWS Load Balancer Controller installation guide](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/)
for the current release and matching IAM policy before upgrading.

Download and create the controller IAM policy once per AWS account:

```bash
LBC_VERSION=v3.6.3
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
curl -fsSLo iam_policy.json \
  "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json"
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
rm iam_policy.json
```

If that IAM policy already exists, do not run `create-policy` again; verify its
permissions and use its ARN in the next command. Create the controller
ServiceAccount and IRSA role:

```bash
POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" --region="$AWS_REGION" \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn="$POLICY_ARN" \
  --override-existing-serviceaccounts --approve
```

Install the controller, passing the region and VPC explicitly so it does not
need to discover them from EC2 instance metadata:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --wait
kubectl rollout status deployment/aws-load-balancer-controller \
  --namespace kube-system --timeout=180s
```

### 6. Create production secrets in AWS Secrets Manager

Create these two JSON secrets in `us-east-1` using the AWS Secrets Manager
console or an approved secure process. Do not put their values in Kubernetes
manifests, command history, or source control:

- Secret name `production/postgres`, with a `DATABASE_URL` property containing
  `postgresql+psycopg://<db_username>:<URL-encoded-db_password>@<rds_endpoint>/postgres`.
  Get the endpoint with
  `terraform -chdir=terraform/modules output -raw rds_endpoint`. This Terraform
  configuration leaves the PostgreSQL database name unset, so the RDS default
  database is `postgres`.
- Secret name `production/application`, with a `JWT_SECRET` property. Generate
  a strong value, for example with `python -c "import secrets; print(secrets.token_hex(32))"`.

The database URL must use the private RDS endpoint, not `localhost`. Ensure
the RDS security group allows TCP 5432 from the EKS worker nodes; do not open
PostgreSQL to `0.0.0.0/0`. The current Terraform security group rule refers to
`aws_security_group.eks_nodes`, while the managed node group does not attach
that security group. Before deploying, update the `aws_security_group.rds`
ingress rule in `terraform/modules/security_groups.tf` to use the EKS cluster
security group attached to its managed nodes:

```hcl
security_groups = [aws_eks_cluster.main.vpc_config[0].cluster_security_group_id]
```

Then review and apply the Terraform change from the repository root:

```bash
terraform -chdir=terraform/modules plan
# Review the plan before applying.
terraform -chdir=terraform/modules apply
```

If using a customer-managed KMS key for these secrets, grant the External
Secrets role `kms:Decrypt` on that key.

### 7. Apply the production overlay

Do not apply the obsolete `kubernetes/secrets/` directory; it contains older
secret manifests and static-credential configuration. Create the namespace,
then apply the cluster-scoped store separately so Kustomize cannot assign it a
namespace:

```bash
kubectl apply -f ./kubernetes/overlays/production/namespace.yaml
kubectl apply -f ./kubernetes/overlays/production/cluster-scoped/cluster-secret-store.yaml
kubectl wait --for=condition=Ready \
  clustersecretstore/aws-secrets-manager --timeout=180s
kubectl apply -k ./kubernetes/overlays/production
```

Wait for secrets and workloads to become ready:

```bash
kubectl wait --for=condition=Ready externalsecret/application-secret \
  --namespace production --timeout=180s
kubectl get secret application-secret --namespace production
kubectl rollout status deployment/backend --namespace production --timeout=300s
kubectl rollout status deployment/frontend --namespace production --timeout=300s
kubectl get pods,ingress --namespace production
```

The ExternalSecret creates the Kubernetes `application-secret` consumed by
the backend. The Ingress routes `/api` to FastAPI and other paths to the
frontend; its ALB health-check path is `/api/health`. Once the ALB is
provisioned, `kubectl get ingress application-ingress -n production` shows its
DNS address. With the current internal scheme, access that address from
within the VPC or a connected network.

The overlay also creates CPU-based HorizontalPodAutoscalers. Install a
Kubernetes-version-compatible metrics-server if you want those autoscalers to
scale; its absence does not prevent the application Deployments from running.

Create the initial application login if needed:

```bash
kubectl exec -it --namespace production deployment/backend -- python create_user.py
```

### 8. Deploy later image updates

The production overlay uses the mutable `latest` tag and sets
`imagePullPolicy: Always`. After the ECR publishing workflow succeeds, restart
the deployments to make Kubernetes pull the new image:

```bash
kubectl rollout restart deployment/backend deployment/frontend \
  --namespace production
kubectl rollout status deployment/backend --namespace production
kubectl rollout status deployment/frontend --namespace production
```

For reproducible releases and rollbacks, change both `newTag` values in
`overlays/production/kustomization.yaml` to the same commit-SHA tag published
by CI, then apply the overlay. The image names and deployment tags must refer
to images that exist in the configured ECR repositories.
