locals {
  app_name          = "beanstalk-nodejs-app"
  environment       = "dev"
  state_bucket_name = "beanstalk-nodejs-app-tfstate-682227955413"

  # The repository uses immutable OIDC subjects, so the claim prefix includes
  # the owner and repository numeric IDs. Keep both prefixes while the
  # repository moves to the devops-boilerplate organization; the legacy prefix
  # is removed once the transfer is complete.
  github_subject_prefixes = [
    "repo:ebouther@14021292/beanstalk-nodejs-app@1467806025",
    "repo:devops-boilerplate@360516626/beanstalk-nodejs-app@1467806025",
  ]

  tags = {
    Project     = local.app_name
    Environment = local.environment
    Repository  = "github.com/devops-boilerplate/beanstalk-nodejs-app"
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
  github_subject_claims = concat(
    [for prefix in local.github_subject_prefixes : "${prefix}:ref:refs/heads/main"],
    [for prefix in local.github_subject_prefixes : "${prefix}:environment:dev"],
  )

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
