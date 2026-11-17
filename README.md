# CloudDeploy

CloudDeploy is a cloud engineering project that takes a small TypeScript API from local development to a Kubernetes release on AWS. The deployment path uses Terraform, GitHub Actions, GitHub Container Registry, and AWS Systems Manager.

## Implementation milestones

- [x] Scaffold the repository.
- [ ] Build and test the Express API.
- [ ] Build and smoke-test the production Docker image.
- [ ] Deploy to kind and verify probes, recovery, and scaling.
- [ ] Build and validate Terraform for AWS EC2 and K3s.
- [ ] Set up pull request validation and digest-pinned releases.
- [ ] Verify a rolling deployment and recovery to the last successful release.
- [ ] Configure CloudWatch and document load tests, demo results, and cleanup.

## Repository layout

| Path | Purpose |
| --- | --- |
| `app/` | Express API, application tests, and Docker build |
| `infrastructure/terraform/` | AWS resources and K3s bootstrap |
| `kubernetes/` | Workload, configuration, service, and autoscaling manifests |
| `scripts/` | Deployment, recovery, smoke tests, and load tests |
| `.github/workflows/` | Pull request validation, application releases, and infrastructure checks |
| `docs/` | Architecture, operations runbook, and demo results |

Local validation comes first. AWS provisioning is a separate, explicitly approved operation.
