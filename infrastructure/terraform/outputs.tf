output "aws_region" {
  value = var.aws_region
}

output "instance_id" {
  value = aws_instance.k3s.id
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "deployment_role_arn" {
  value = aws_iam_role.github.arn
}

output "deployment_document" {
  value = aws_ssm_document.deploy.name
}

output "deployment_log_group" {
  value = aws_cloudwatch_log_group.deployments.name
}

output "rollback_document" {
  value = aws_ssm_document.rollback.name
}
