variable "aws_region" {
  description = "AWS region for the CloudDeploy sandbox."
  type        = string
}

variable "aws_account_id" {
  description = "Authorized AWS sandbox account ID. The provider rejects other accounts."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Use a 12-digit AWS account ID."
  }
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to deploy from main."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Use the GitHub owner/repository format."
  }
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN in this account, or null to create one."
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC. The public subnet uses its first /24."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition = (
      can(cidrnetmask(var.vpc_cidr)) &&
      try(contains(range(16, 25), tonumber(split("/", var.vpc_cidr)[1])), false)
    )
    error_message = "Use an IPv4 CIDR with a prefix from /16 to /24."
  }
}

variable "instance_type" {
  description = "Burstable T3 or T3a instance type compatible with the AMD64 Ubuntu image."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = can(regex("^t3a?\\.", var.instance_type))
    error_message = "Use a T3 or T3a instance type."
  }
}

variable "k3s_version" {
  description = "Exact K3s release installed during bootstrap."
  type        = string
  default     = "v1.36.4+k3s1"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "Use an exact K3s release such as v1.36.4+k3s1."
  }
}

variable "alarm_topic_arn" {
  description = "Optional SNS topic ARN to receive CloudWatch alarm notifications."
  type        = string
  default     = null
}
