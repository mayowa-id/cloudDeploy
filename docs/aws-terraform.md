# AWS Terraform

## Configuration

This sandbox uses one Ubuntu 24.04 EC2 instance running K3s, a dedicated VPC, a private versioned S3 release bucket, AWS Systems Manager, and CloudWatch. The host has outbound internet access and zero inbound security group rules. The GitHub deployment role trusts only `refs/heads/main` in the configured repository.

From the repository root, initialize and validate locally:

```sh
cd infrastructure/terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform test
```

If WSL reports a provider read or allocation error on a Windows-mounted checkout, run `export TF_DATA_DIR="$HOME/.cache/clouddeploy/terraform-aws"` before initializing. Use the same setting for subsequent Terraform commands from that checkout.

Copy [sandbox.example.tfvars](../infrastructure/terraform/sandbox.example.tfvars) to `sandbox.tfvars`. Set the authorized AWS account ID, region, and exact GitHub owner/repository. If the account already has a GitHub Actions OIDC provider, set its ARN so Terraform can reuse it. Set `alarm_topic_arn` if you want SNS notifications. The default VPC is `10.20.0.0/16`. Keep it separate from the K3s pod and service CIDRs if you override it.

## Review and provision

Use your AWS sandbox login in WSL. If you use a named profile, export it with `export AWS_PROFILE=<profile-name>`. For IAM Identity Center profiles, authenticate with `aws sso login --profile <profile-name>` first.

```sh
aws sts get-caller-identity
terraform plan -var-file=sandbox.tfvars -out=tfplan
terraform show tfplan
```

Confirm the AWS account, planned resources, and charges. With explicit approval, provision the reviewed plan:

```sh
terraform apply tfplan
terraform output
```

The EC2 instance, encrypted storage, public IPv4 address, and operational services can incur charges. Terraform state starts local. Keep the state and plan files out of Git and retain access to the state for cleanup.

## Verify bootstrap

In the AWS console, open a Systems Manager Session Manager shell to the Terraform output `instance_id`. Run:

```sh
sudo cloud-init status --wait
sudo systemctl is-active k3s
sudo k3s kubectl get nodes
```

If bootstrap fails, inspect `/var/log/cloud-init-output.log` and `sudo journalctl -u k3s`. Run a second Terraform plan with the same inputs and check for unexpected changes. Canonical's stable AMI lookup can propose a replacement when a newer image is published, so review the saved plan before any later apply. A user-data change also replaces this single-node host.

## Release interface

The deployment role can upload `releases/<40-character Git SHA>/manifests.yaml` to the artifact bucket and invoke only the CloudDeploy SSM document on this instance. Publish a manifest bundle with the Namespace first and a digest-pinned image. Pass the same SHA as the document's `ReleaseId` parameter. Enable CloudWatch output on the invocation and set the log group to Terraform's `deployment_log_group` output.

Bootstrap installs the deployment and manual Deployment rollback commands. The deployment command waits for rollout success. Commit verification and automatic restoration of the last successful manifest bundle are part of the release recovery phase.

## Cleanup

Before destroying a used sandbox, confirm the artifacts you want to retain and empty all objects, versions, and delete markers from the release bucket. Then review a destruction plan:

```sh
terraform plan -destroy -var-file=sandbox.tfvars -out=destroy.tfplan
terraform show destroy.tfplan
```

Apply the destruction plan once you have explicitly approved it. Check EC2, S3, Systems Manager, and CloudWatch for leftover demo resources.
