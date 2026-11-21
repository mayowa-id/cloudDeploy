mock_provider "aws" {
  override_during = plan

  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }

  mock_data "aws_ssm_parameter" {
    defaults = { value = "ami-0123456789abcdef0" }
  }

  mock_resource "aws_iam_openid_connect_provider" {
    defaults = { arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com" }
  }

  mock_resource "aws_s3_bucket" {
    defaults = {
      bucket = "clouddeploy-artifacts-test"
      arn    = "arn:aws:s3:::clouddeploy-artifacts-test"
    }
  }
}

variables {
  aws_region        = "us-east-1"
  aws_account_id    = "123456789012"
  github_repository = "example/clouddeploy"
}

run "sandbox_foundation" {
  command = plan

  assert {
    condition = (
      aws_subnet.public.cidr_block == "10.20.0.0/24" &&
      length(aws_security_group.k3s.ingress) == 0 &&
      aws_instance.k3s.metadata_options[0].http_tokens == "required" &&
      aws_instance.k3s.root_block_device[0].encrypted
    )
    error_message = "The instance must use the expected subnet, zero ingress, IMDSv2, and encrypted storage."
  }

  assert {
    condition = (
      startswith(aws_instance.k3s.user_data, "#cloud-config\n") &&
      length(aws_instance.k3s.user_data) < 16384 &&
      length(yamldecode(aws_instance.k3s.user_data).write_files) == 6 &&
      yamldecode(aws_instance.k3s.user_data).runcmd[0][1] == var.k3s_version
    )
    error_message = "EC2 user data must fit the size limit and include the pinned K3s bootstrap and its files."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.artifacts.block_public_policy &&
      aws_s3_bucket_public_access_block.artifacts.block_public_acls &&
      aws_s3_bucket_versioning.artifacts.versioning_configuration[0].status == "Enabled" &&
      jsondecode(aws_iam_role.github.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:example/clouddeploy:ref:refs/heads/main"
    )
    error_message = "The release bucket must be private and versioned, and the OIDC role must trust only the configured main branch."
  }
}
