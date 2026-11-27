data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  partition      = data.aws_partition.current.partition
  region         = data.aws_region.current.region
  name_prefix    = "${var.app_name}-${var.environment}"
  container_name = var.app_name

  tags = merge(
    {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )

  cluster_arn   = aws_ecs_cluster.main.arn
  service_arn   = "arn:${local.partition}:ecs:${local.region}:${local.account_id}:service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  task_arn_glob = "arn:${local.partition}:ecs:${local.region}:${local.account_id}:task/${aws_ecs_cluster.main.name}/*"

  codedeploy_app_arn = "arn:${local.partition}:codedeploy:${local.region}:${local.account_id}:application:${aws_codedeploy_app.app.name}"
  codedeploy_dg_arn  = "arn:${local.partition}:codedeploy:${local.region}:${local.account_id}:deploymentgroup:${aws_codedeploy_app.app.name}/${aws_codedeploy_deployment_group.app.deployment_group_name}"
}
