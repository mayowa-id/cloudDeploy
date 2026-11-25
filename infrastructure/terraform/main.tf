data "aws_partition" "current" {}

locals {
  github_issuer   = "token.actions.githubusercontent.com"
  github_audience = "sts.amazonaws.com"
  release_objects = "${aws_s3_bucket.artifacts.arn}/releases/*/manifests.yaml"
}
