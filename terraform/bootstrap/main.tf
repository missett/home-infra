terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.66.0"
    }
  }

  backend "s3" {
    encrypt = true
    #     bucket = ""
    #     key    = ""
  }
}

locals {
  account = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

resource "aws_s3_account_public_access_block" "example" {
  block_public_acls   = true
  block_public_policy = true
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "tfstate-${local.account}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_state" {
  name                        = "tfstate-lock"
  hash_key                    = "LockID"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true

  attribute {
    name = "LockID"
    type = "S"
  }
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid       = "RequireEncryptedTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "Bool"
      values   = ["false"]
      variable = "aws:SecureTransport"
    }
  }

  statement {
    sid       = "RequireEncryptedStorage"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.terraform_state.bucket}/*"]

    principals {
      identifiers = ["*"]
      type        = "AWS"
    }

    condition {
      test     = "StringNotEquals"
      values   = ["AES256"]
      variable = "s3:x-amz-server-side-encryption"
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state.json
}

resource "aws_iam_user" "terraform_admin" {
  name = "terraform-admin"
}

resource "aws_iam_access_key" "terraform_admin" {
  user = aws_iam_user.terraform_admin.name
}

resource "aws_ssm_parameter" "terraform_admin_access_key" {
  name  = "/users/terraform-admin/access-key"
  type  = "SecureString"
  value = aws_iam_access_key.terraform_admin.id
}

resource "aws_ssm_parameter" "terraform_admin_secret_key" {
  name  = "/users/terraform-admin/secret-key"
  type  = "SecureString"
  value = aws_iam_access_key.terraform_admin.secret
}

resource "aws_iam_role" "terraform_admin" {
  name                 = "terraform-admin"
  max_session_duration = 3600

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_user.terraform_admin.arn
        }
        # NB. the addition of the MFA to the IAM user account is manually managed like this
        # (you will need to use creds that have permission to modify iam accounts)-
        # 1. aws iam create-virtual-mfa-device --virtual-mfa-device-name terraform-admin --outfile mfa.png --bootstrap-method QRCodePNG
        # 2. use the png file that is created to add the setup into your mfa app of choice, remember to save the serial of the mfa devcie too
        # 3. aws iam enable-mfa-device  --user-name terraform-admin --serial-number xxx --authentication-code1 xxx --authentication-code2 xxx
        # 4. you can now use the get-session-token call with mfa settings appended like so-
        # 5. aws sts assume-role --role-arn=arn:aws:iam::443370677421:role/terraform-admin --role-session-name=terraform --duration-seconds=3600 --serial-number xxx --token-code xxx
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" : true
          }
        }
      },
    ]
  })
}

