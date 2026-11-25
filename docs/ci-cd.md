# CI and releases

## Pull requests

Application CI runs npm lint, type checks, tests, and a dependency audit. It builds the Docker image, validates the Kubernetes manifests against a temporary kind cluster, and exercises release recovery. It deploys a healthy release, forces the next rollout to fail readiness, and verifies that the API reports the original commit after recovery. Terraform changes run formatting, validation, and mocked security assertions. Configure branch protection on `main` to require the application check. The Terraform check runs only when relevant files change.

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
| `CLOUDDEPLOY_ROLLBACK_DOCUMENT` | `rollback_document` output |
| `CLOUDDEPLOY_LOG_GROUP` | `deployment_log_group` output |

Set `CLOUDDEPLOY_AWS_DEPLOY_ENABLED=true` when ready. The AWS role trusts the repository's `main` branch via OIDC. The workflow stores the release manifest in S3, runs the scoped SSM document, and reports the result after rollout and in-cluster smoke checks. See the CloudWatch log group for command output.

The demo keeps local Terraform state. Generate AWS plans in the authorized sandbox checkout that owns the state, as described in the [Terraform guide](aws-terraform.md). Infrastructure CI runs its mock plan with no AWS credentials.


## Recover a release

The EC2 host records the current and previous verified releases under `/var/lib/clouddeploy/releases`. A release becomes current after Kubernetes rollout and the health, readiness, and commit checks pass. If applying or verifying a candidate fails, the deploy command reapplies the current verified manifest and checks that release again. GitHub Actions still reports the candidate as failed. Check the CloudWatch command output for the recovery result. If the first deployment fails, there is no verified release to restore.

To return to the previous verified release, run **Roll back CloudDeploy** in GitHub Actions from `main` after any active release finishes. The workflow uses the AWS deployment opt-in. To roll back directly, open an SSM shell on the host and run `sudo /usr/local/bin/clouddeploy-rollback`. The command verifies the restored release before updating the release record. Release history lives on the EC2 root volume and starts fresh after instance replacement. Recovery reapplies the saved resources. It does not prune resources introduced by a manifest or restore application data.
