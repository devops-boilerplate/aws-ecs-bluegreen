# Values consumed by scripts/setup-github-env.sh to configure the GitHub
# environment variables used by the workflows.

output "aws_region" {
  value = module.app.aws_region
}

output "alb_name" {
  value = module.app.alb_name
}

output "alb_dns_name" {
  value = module.app.alb_dns_name
}

output "ecr_repository_name" {
  value = module.app.ecr_repository_name
}

output "ecs_cluster_name" {
  value = module.app.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.app.ecs_service_name
}

output "task_definition_family" {
  value = module.app.task_definition_family
}

output "codedeploy_application" {
  value = module.app.codedeploy_application
}

output "codedeploy_deployment_group" {
  value = module.app.codedeploy_deployment_group
}

output "github_app_role_arn" {
  value = module.app.github_app_role_arn
}

output "github_terraform_role_arn" {
  value = module.app.github_terraform_role_arn
}

output "container_name" {
  value = module.app.container_name
}

output "container_port" {
  value = module.app.container_port
}
