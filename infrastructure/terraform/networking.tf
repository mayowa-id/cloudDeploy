resource "aws_vpc" "clouddeploy" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "clouddeploy"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.clouddeploy.id
  cidr_block = cidrsubnet(var.vpc_cidr, 24 - tonumber(split("/", var.vpc_cidr)[1]), 0)

  tags = {
    Name = "clouddeploy-public"
  }
}

resource "aws_internet_gateway" "clouddeploy" {
  vpc_id = aws_vpc.clouddeploy.id

  tags = {
    Name = "clouddeploy"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.clouddeploy.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.clouddeploy.id
  }

  tags = {
    Name = "clouddeploy-public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "k3s" {
  name        = "clouddeploy-k3s"
  description = "CloudDeploy K3s host, managed through Systems Manager"
  vpc_id      = aws_vpc.clouddeploy.id
  ingress     = []
}

resource "aws_vpc_security_group_egress_rule" "web" {
  for_each = {
    http  = 80
    https = 443
  }

  security_group_id = aws_security_group.k3s.id
  description       = "Outbound ${upper(each.key)} for bootstrap and cloud services"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}
