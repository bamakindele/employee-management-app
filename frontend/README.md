# Employee Management frontend

This directory contains the React application built with Vite.

## Local development

Install dependencies and start the development server:

```bash
npm ci
npm run dev
```

The local frontend uses `http://localhost:5174` by default. See the repository
[README](../README.md) for backend and database setup.

## Build and lint

```bash
npm run build
npm run lint
```

The GitHub Actions **CI Pipeline** runs the production build as part of its
application checks.

## Docker and Amazon ECR

The frontend Dockerfile is in this directory. On pushes to `main`, after the
application checks pass, the **Build and publish ECR images** job in
`.github/workflows/ci.yml` builds and scans the frontend image and pushes it to
the AWS ECR repository named `frontend` in `us-east-1`. It publishes both the
commit-SHA tag and `latest`. See [Terraform documentation](../terraform/README.md)
for OIDC and ECR setup.
