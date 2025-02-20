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

