# CloudDeploy

CloudDeploy is a portfolio project for deploying a TypeScript API to Kubernetes. The local workflow uses Docker and kind. The planned AWS workflow uses Terraform, K3s on EC2, GitHub Actions, and Systems Manager.

## Quick start

With Docker and Docker Compose, run from the repository root:

```sh
docker compose up --build --wait
curl --fail http://127.0.0.1:3000/health
docker compose down
```

## Guides

- [Local development](docs/local-development.md) covers Node.js, Docker, API endpoints, and configuration.
- [Local Kubernetes](docs/local-kubernetes.md) covers kind, probes, pod recovery, scaling, and Metrics Server.
- [AWS Terraform](docs/aws-terraform.md) covers the network foundation and AWS setup.

## Project status

- **Verified locally** — Express API and tests, non-root Docker image, and deployment to kind with pod recovery, manual scaling, and live HPA metrics.
- **AWS infrastructure** — Terraform for EC2 and K3s passes local validation. A sandbox plan and approved apply are pending.
- **Planned** — GitHub Actions validation and digest-pinned releases, automated rollback, CloudWatch monitoring, load tests, and cleanup.
