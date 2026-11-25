resource "aws_cloudwatch_log_group" "deployments" {
  name              = "/clouddeploy/ssm/deployments"
  retention_in_days = 14
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "clouddeploy-high-cpu"
  alarm_description   = "K3s host CPU is at least 80 percent for three consecutive periods."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  dimensions          = { InstanceId = aws_instance.k3s.id }
}

resource "aws_cloudwatch_metric_alarm" "status" {
  alarm_name          = "clouddeploy-failed-status-check"
  alarm_description   = "The K3s host has failed consecutive EC2 status checks."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = var.alarm_topic_arn == null ? [] : [var.alarm_topic_arn]
  dimensions          = { InstanceId = aws_instance.k3s.id }
}
