resource "aws_ssm_document" "deploy" {
  name            = "CloudDeploy-DeployRelease"
  document_type   = "Command"
  document_format = "JSON"
  target_type     = "/AWS::EC2::Instance"

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Deploy a CloudDeploy release by full Git commit SHA."
    parameters = {
      ReleaseId = {
        type              = "String"
        description       = "Full lowercase Git commit SHA."
        interpolationType = "ENV_VAR"
        allowedPattern    = "^[0-9a-f]{40}$"
      }
    }
    mainSteps = [{
      action       = "aws:runShellScript"
      name         = "DeployRelease"
      precondition = { StringEquals = ["platformType", "Linux"] }
      inputs = {
        timeoutSeconds = "600"
        runCommand     = ["exec /usr/local/bin/clouddeploy-deploy \"$SSM_ReleaseId\""]
      }
    }]
  })
}
