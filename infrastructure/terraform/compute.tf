data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "k3s" {
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.k3s.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.k3s.name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    settings = indent(6, jsonencode({
      bucket = aws_s3_bucket.artifacts.bucket
      region = var.aws_region
    }))
    bootstrap = indent(6, replace(file("${path.module}/bootstrap.sh"), "\r\n", "\n"))
    deploy    = indent(6, replace(file("${path.module}/../../scripts/deploy.sh"), "\r\n", "\n"))
    rollback  = indent(6, replace(file("${path.module}/../../scripts/rollback.sh"), "\r\n", "\n"))
    smoke     = indent(6, replace(file("${path.module}/../../scripts/smoke-test.sh"), "\r\n", "\n"))
    version   = var.k3s_version
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted             = true
    volume_type           = "gp3"
    volume_size           = 24
    delete_on_termination = true
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = {
    Name = "clouddeploy-k3s"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.web,
    aws_iam_role_policy_attachment.ssm,
    aws_iam_role_policy.k3s,
  ]
}
