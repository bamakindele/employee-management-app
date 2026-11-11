# Employee Management App

## Local development

Start the PostgreSQL database used by the app:

```powershell
docker compose up -d postgres
```

In PowerShell, start the backend from the project root:

```powershell
cd backend-fastapi
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe -m uvicorn main:app --reload --host 127.0.0.1 --port 8001
```

The execution-policy change applies only to the current PowerShell process and
allows the virtual environment activation script to run. If `DATABASE_URL` is
already set in that terminal, clear it before launching so the backend reads
the root `.env` instead:

```powershell
Remove-Item Env:DATABASE_URL -ErrorAction SilentlyContinue
```

In a Bash terminal, start the frontend from the `frontend` directory:

```bash
cd frontend
npm run dev
```

Local development URLs:

- Frontend: `http://localhost:5174`
- Backend API: `http://localhost:8001`
- FastAPI docs: `http://localhost:8001/docs`

Create a sign-in account (called a user in the database) from the backend
directory in PowerShell:

```powershell
cd backend-fastapi
.\.venv\Scripts\python.exe create_user.py
```

The script prompts for a username and password. It creates a login account;
employee directory records are added separately from the signed-in frontend.

## Run with Docker

Copy `.env.example` to `.env`, set strong values for `POSTGRES_PASSWORD` and
`JWT_SECRET`, then start the application:

```powershell
docker compose up --build
```

Open the frontend at `http://localhost:5173`. The API is available at
`http://localhost:8000`, and its FastAPI docs are at
`http://localhost:8000/docs`. PostgreSQL runs on port `5432`.

Create a sign-in account while the Docker backend is running:

```powershell
docker compose exec backend python create_user.py
```

The script prompts for a username and password. Employee directory records are
added separately from the signed-in frontend.

## CI and publishing images to Amazon ECR

The GitHub Actions workflow at `.github/workflows/ci.yml` runs application
checks for pull requests and pushes to `main`. For a push to `main`, it also
runs the **Build and publish ECR images** job after the checks pass. That job
builds and scans the frontend and backend container images, then pushes them
to the `frontend` and `backend` ECR repositories in `us-east-1`.

Each image is pushed with both the triggering commit SHA and the rolling
`latest` tag. Trivy reports HIGH and CRITICAL findings, but currently does not
fail the job because its `exit-code` is set to `0`.

To enable publishing:

1. Provision the GitHub OIDC provider, IAM role, and ECR push policy using the
   instructions in [terraform/README.md](terraform/README.md).
2. In the GitHub repository, open **Settings → Secrets and variables →
   Actions**, add a repository secret named `AWS_ROLE_ARN`, and set its value
   to the IAM role ARN created by Terraform (for example,
   `arn:aws:iam::<account-id>:role/github-actions-ecr-role`).
3. Ensure the `frontend` and `backend` ECR repositories exist in the
   same AWS account and `us-east-1` region as the IAM role.
4. Push a commit to `main` and inspect the **Build and publish ECR images** job
   in the **CI Pipeline** run. Pull-request runs do not publish images.

The workflow uses short-lived credentials through GitHub OIDC; do not add
long-lived AWS access keys to GitHub secrets. If authentication fails, check
the `AWS_ROLE_ARN` secret and that the IAM trust policy allows this repository's
`main` branch. If a push fails, check the ECR repository names, AWS region, and
the role's ECR permissions.

## PostgreSQL client and server

`psql 15.19` is the PostgreSQL command-line client available in PowerShell;
it is a client program, not a database server. pgAdmin connects to the
PostgreSQL 18 server selected in its registered server connection. Docker
Compose separately runs a PostgreSQL 15 server in its `postgres` container.

The server version and data depend on the host and port configured in the
client. Because Compose publishes its PostgreSQL container on host port `5432`,
a separate local PostgreSQL service cannot use that same port at the same time.

# Trivy Scan Findings
During CI pipeline build, Trivy scan detected a few dependencies that are vulnerable
Backend: jaraco.context -- CVE-2026-23949
Backend: wheel -- CVE-2026-24049
Frontend: brotli-libs -- CVE-2026-111497
Frontend: curl -- CVE-2026-92392

## Kubernetes

The Kustomize overlays separate local Docker Desktop development from
production on EKS. See [kubernetes/README.md](kubernetes/README.md) for image
builds, local secret setup, deployment commands, and EKS prerequisites.