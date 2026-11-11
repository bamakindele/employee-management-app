# Kubernetes deployment

The Kustomize overlays keep local development and EKS production separate:

- `overlays/development` uses images built into Docker Desktop's local image
  store and runs PostgreSQL in the cluster with a persistent volume claim.
- `overlays/production` pulls frontend and backend images from private ECR,
  connects to the production database through a secret-provided URL, and uses
  an AWS Application Load Balancer Ingress. PostgreSQL is not deployed in EKS.

## Docker Desktop development

Run these commands from the repository root. Docker Desktop Kubernetes must be
using the same local Docker image store.

```powershell
# Build the docker image
docker build --tag backend:dev .\backend-fastapi

# Vite hardcoded the localhost address/port into the docker image(local)
docker build --build-arg VITE_API_URL=http://localhost:8000/api --tag frontend:dev .\frontend
```

Create a local-only secret before applying the overlay. Use a strong JWT value
and a URL-safe PostgreSQL password; do not commit the values:

```powershell
kubectl create namespace development --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic application-secret --namespace development `
# from bash terminal, generate a JWT_Secret using: 'openssl rand -hex 32'
# update .env with JWT_SECRET=replace-with-a-long-random-value `
  
kubectl apply -k .\kubernetes\overlays\development
```

Replace both example secret values before running the command. The values are
passed on the command line; avoid using this pattern on a shared machine.
After creating the secret, apply or re-apply the overlay. The PostgreSQL claim
uses the cluster's default storage class.

To open the app, run each port-forward in a separate terminal:

```powershell
Application is currently running on K8 cluster and not directly accessible.
Port forwarding is required to make the application accessible on local PC.
kubectl port-forward --namespace development service/frontend-service 5173:80
kubectl port-forward --namespace development service/backend-service 8000:8000
```

Browse to `http://localhost:5173`. The locally built frontend calls the
forwarded API at `http://localhost:8000/api`.

```Create user to access application
kubectl exec -it -n development deployment/backend -- python create_user.py```

## EKS production

The production image names match the Terraform ECR repositories:
`frontend` and `backend-fastapi` in `us-east-1`. The EKS worker-node role must
have permission to pull from these private repositories. Terraform currently
attaches the ECR read-only managed policy to that role.

Before applying the production overlay:

1. Install the External Secrets Operator and AWS Load Balancer Controller,
   including their required CRDs and IAM permissions. Install metrics-server
   as well if you want the HorizontalPodAutoscalers to scale from CPU metrics.
2. Associate the `external-secrets` service account in the `external-secrets`
   namespace with an IAM role allowed to read only the required Secrets Manager
   secrets. The cluster-scoped store manifest uses that service account via
   its projected token; it does not use static AWS access keys.
3. Create Secrets Manager JSON values at `production/postgres` with a
   `DATABASE_URL` property, and `production/application` with a `JWT_SECRET`
   property. `DATABASE_URL` must be a SQLAlchemy-compatible PostgreSQL URL for
   the private production database. Do not put secret values in Kubernetes
   manifests or source control.
4. Ensure the EKS cluster can reach the private database and that its security
   group rules permit PostgreSQL traffic from the worker nodes.

Apply the cluster-scoped store separately; keeping it outside the namespaced
overlay prevents Kustomize from assigning it a namespace:

```powershell
kubectl apply -f .\kubernetes\overlays\production\cluster-scoped\cluster-secret-store.yaml
kubectl apply -k .\kubernetes\overlays\production
```

The frontend image is built in CI with `VITE_API_URL=/api`. The Ingress sends
`/api` traffic to FastAPI and all other paths to the frontend, so both use the
same ALB hostname. Its health-check endpoint is `/api/health`.

CI publishes immutable commit-SHA tags as well as `latest`. The overlay uses
`latest` by default; after publishing a new image, either set the Deployments
to the corresponding commit-SHA tags or restart them to pull the updated
`latest` image:

```powershell
kubectl rollout restart deployment/backend deployment/frontend --namespace production
kubectl rollout status deployment/backend --namespace production
kubectl rollout status deployment/frontend --namespace production
```

For production rollbacks and reproducible releases, prefer deploying the
commit-SHA image tags rather than the mutable `latest` tag.
