# CloudDeploy

CloudDeploy is a portfolio project for deploying a TypeScript API to Kubernetes. The local workflow uses Docker and kind. Terraform defines the AWS EC2 and K3s infrastructure, and GitHub Actions runs checks and releases.

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
- [CI and releases](docs/ci-cd.md) covers pull request checks, GHCR publishing, and AWS deployment.
