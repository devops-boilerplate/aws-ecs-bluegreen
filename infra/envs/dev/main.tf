locals {
  app_name          = "beanstalk-nodejs-app"
  environment       = "dev"
  state_bucket_name = "beanstalk-nodejs-app-tfstate-682227955413"

  tags = {
    Project     = local.app_name
    Environment = local.environment
    Repository  = "github.com/ebouther/beanstalk-nodejs-app"
    ManagedBy   = "terraform"
  }
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "app" {
  source = "../../modules/app"

  app_name          = local.app_name
  environment       = local.environment
  state_bucket_name = local.state_bucket_name

  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  github_subject_claims = [
    "repo:ebouther/beanstalk-nodejs-app:ref:refs/heads/main",
    "repo:ebouther/beanstalk-nodejs-app:environment:dev",
  ]

  # dev: one task, all-at-once deployments, short-lived previous task set.
  desired_count                 = 1
  min_count                     = 1
  max_count                     = 2
  log_retention_days            = 30
  deployment_config_name        = "CodeDeployDefault.ECSAllAtOnce"
  blue_termination_wait_minutes = 0

  ecr_force_delete           = true
  enable_deletion_protection = false

  alarm_emails = var.alarm_emails
  tags         = local.tags
}
