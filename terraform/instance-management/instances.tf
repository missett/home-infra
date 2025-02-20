data "aws_iam_policy_document" "ssm_instance_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "ssm_instance" {
  name               = "ssm-instance"
  assume_role_policy = data.aws_iam_policy_document.ssm_instance_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_instance_core" {
  role       = aws_iam_role.ssm_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ssm_activation" "activations" {
  for_each = {
    ubuntuvm = {}
    macbookair ={}
  }

  name               = each.key
  iam_role           = aws_iam_role.ssm_instance.id
  registration_limit = "1"
  depends_on         = [aws_iam_role_policy_attachment.ssm_instance_core]
}

resource "aws_ssm_parameter" "ssm_activation_id" {
  for_each = aws_ssm_activation.activations

  name  = "/home-infra/instance/activation/${each.key}/id"
  type  = "SecureString"
  value = aws_ssm_activation.activations[each.key].id
}

resource "aws_ssm_parameter" "ssm_activation_code" {
  for_each = aws_ssm_activation.activations

  name  = "/home-infra/instance/activation/${each.key}/code"
  type  = "SecureString"
  value = aws_ssm_activation.activations[each.key].activation_code
}
