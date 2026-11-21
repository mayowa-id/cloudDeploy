# CI and releases

## Pull requests

Application CI runs npm lint, type checks, tests, and a dependency audit. It builds the Docker image, validates the Kubernetes manifests against a temporary kind cluster, and checks the running API. Terraform changes run formatting, validation, and mocked security assertions. Configure branch protection on `main` to require the application check. The Terraform check runs only when relevant files change.

## Enable releases

A push to `main` repeats application CI before publishing. Set the repository Actions variable `CLOUDDEPLOY_PUBLISH_ENABLED=true` to allow publishing the sample image to GHCR. The first published package may be private. Make it public in GitHub's package settings before enabling AWS deployment so K3s can pull it anonymously. The workflow tags each image with the full Git SHA and deploys by digest.

After an approved sandbox apply and a ready Systems Manager instance, set these repository Actions variables from the Terraform outputs:

| Variable | Value |
| --- | --- |
| `CLOUDDEPLOY_AWS_REGION` | `aws_region` output |
| `CLOUDDEPLOY_AWS_ACCOUNT_ID` | Authorized sandbox account ID |
| `CLOUDDEPLOY_DEPLOY_ROLE_ARN` | `deployment_role_arn` output |
| `CLOUDDEPLOY_ARTIFACT_BUCKET` | `artifact_bucket` output |
| `CLOUDDEPLOY_INSTANCE_ID` | `instance_id` output |
| `CLOUDDEPLOY_SSM_DOCUMENT` | `deployment_document` output |
| `CLOUDDEPLOY_LOG_GROUP` | `deployment_log_group` output |

Set `CLOUDDEPLOY_AWS_DEPLOY_ENABLED=true` when ready. The AWS role trusts the repository's `main` branch via OIDC. The workflow stores the release manifest in S3, runs the scoped SSM document, and reports the result after rollout and in-cluster smoke checks. See the CloudWatch log group for command output.

The demo keeps local Terraform state. Generate AWS plans in the authorized sandbox checkout that owns the state, as described in the [Terraform guide](aws-terraform.md). Infrastructure CI runs its mock plan with no AWS credentials.
