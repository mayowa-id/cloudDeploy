# CloudDeploy

CloudDeploy is a cloud engineering project that takes a small TypeScript API from local development to a Kubernetes release on AWS. The deployment path uses Terraform, GitHub Actions, GitHub Container Registry, and AWS Systems Manager.

## Implementation milestones

- [x] Scaffold the repository.
- [x] Build and test the Express API.
- [x] Build and smoke-test the production Docker image.
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

## Run the API locally

With Node.js 22 or newer and npm installed, run these commands from the repository root:

```sh
cd app
npm ci
npm test
npm start
```

If you are starting the API without running the tests, run `npm run build` before `npm start`.

| Endpoint | What it returns |
| --- | --- |
| `GET /` | Application name and description |
| `GET /health` | Liveness status |
| `GET /ready` | HTTP 200 while ready or 503 while draining |
| `GET /version` | Release version, Git commit, environment, and instance |
| `GET /metrics` | Prometheus HTTP request counts and duration histograms |

Try `curl http://localhost:3000/version` or `Invoke-RestMethod http://localhost:3000/version` in PowerShell.

| Environment variable | Default |
| --- | --- |
| `PORT` | `3000` |
| `APP_VERSION` | `1.0.0` |
| `APP_COMMIT` | `local` |
| `APP_ENV` | `local` |
| `INSTANCE_NAME` | Hostname |

Each HTTP response carries an `X-Request-ID` that matches its JSON request log. Metrics use the registered route or `unmatched` as their route label, keeping the number of time series bounded when clients send arbitrary paths. On SIGTERM or SIGINT, the server marks itself unready, stops accepting connections, and allows active requests up to 10 seconds to finish.

## Run the production image locally

From the repository root, build and start the container with Docker Compose:

```sh
docker compose up --build --wait
curl --fail http://127.0.0.1:3000/health
curl --fail http://127.0.0.1:3000/ready
docker compose down
```

If port 3000 is in use, set `CLOUDDEPLOY_HOST_PORT` to a free port before starting Compose and use that port in the curl commands.

With Docker Engine alone, run the container in one terminal and send the health and readiness requests from another:

```sh
docker build -t clouddeploy:local ./app
docker run --rm --stop-timeout 15 -p 127.0.0.1:3000:3000 clouddeploy:local
```

Both stages use the official Node.js 22 Alpine image. The build stage installs dependencies from the lockfile, compiles TypeScript, and prunes development dependencies. The runtime stage copies the compiled JavaScript and production dependencies, runs Node as UID and GID 1000, and checks `/health` with Node's built-in HTTP client. Docker sends SIGTERM directly to Node when the container stops.
