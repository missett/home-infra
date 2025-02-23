resource "aws_cloudwatch_log_group" "ssm_patching" {
  name              = "/ssm/patching"
  retention_in_days = 7
}

data "aws_ssm_patch_baseline" "default_ubuntu_baseline" {
  owner            = "AWS"
  operating_system = "UBUNTU"
  name_prefix      = "AWS-"
}

resource "aws_ssm_patch_group" "ubuntu_patch" {
  baseline_id = data.aws_ssm_patch_baseline.default_ubuntu_baseline.id
  patch_group = "ubuntu-patch-group"
}

resource "aws_ssm_maintenance_window" "patching" {
  name        = "patching"
  schedule    = "cron(0 0 ? * * *)"
  description = "patch window for all devices"
  duration    = 3
  cutoff      = 1
}

resource "aws_ssm_maintenance_window_target" "ubuntu_targets" {
  window_id     = aws_ssm_maintenance_window.patching.id
  resource_type = "INSTANCE"
  description   = "ubuntu patch targets"

  targets {
    key    = "tag:PatchGroup"
    values = ["ubuntu"]
  }
}

resource "aws_ssm_maintenance_window_task" "ubuntu_patching" {
  window_id        = aws_ssm_maintenance_window.patching.id
  description      = "patching"
  task_type        = "RUN_COMMAND"
  task_arn         = "AWS-RunPatchBaseline"
  priority         = 1
  max_concurrency  = "100%"
  max_errors       = "100%"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.ubuntu_targets.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment          = "Ubuntu Patch Baseline"
      document_version = "$LATEST"
      timeout_seconds  = 3600
      
      cloudwatch_config {
        cloudwatch_log_group_name = aws_cloudwatch_log_group.ssm_patching.id
        cloudwatch_output_enabled = true
      }

      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}

resource "aws_ssm_association" "update_ssm_agent_ubuntu" {
  name                = "AWS-UpdateSSMAgent"
  association_name    = "CustomAutoUpdateSSMAgent"
  schedule_expression = "cron(0 12 ? * * *)"
  max_concurrency     = "100%"
  max_errors          = "100%"

  targets {
    key    = "tag:PatchGroup"
    values = ["ubuntu"]
  }
}
