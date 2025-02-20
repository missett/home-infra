resource "aws_iam_user" "ssm_activation" {
  name = "ssm-activation"
}

resource "aws_iam_access_key" "ssm_activation" {
  user = aws_iam_user.ssm_activation.name
}

resource "aws_ssm_parameter" "ssm_activation_access" {
  name  = "/users/ssm-activation/access-key"
  type  = "SecureString"
  value = aws_iam_access_key.ssm_activation.id
}

resource "aws_ssm_parameter" "ssm_activation_secret" {
  name  = "/users/ssm-activation/secret-key"
  type  = "SecureString"
  value = aws_iam_access_key.ssm_activation.secret
}

data "aws_iam_policy_document" "ssm_activation" {
  statement {
    sid       = "GetActivationCredentials"
    effect    = "Allow"
    resources = [
      "arn:aws:ssm:eu-west-2:888577031405:parameter/home-infra/instance/activation/*"
    ] 
    actions = [
      "ssm:GetParameter*",
      "ssm:DescribeParameters",
    ]
  }
}

resource "aws_iam_role" "ssm_activation" {
  name                 = "ssm-activation"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.ssm_activation.arn
        }
      },
    ]
  })

  inline_policy {
    name   = "ssm-activation"
    policy = data.aws_iam_policy_document.ssm_activation.json
  }
}
