output "aws_region" {
  description = "Region of the deployed environment"
  value       = local.region
}

output "container_name" {
  description = "Container name inside the task definition"
  value       = local.container_name
}

output "container_port" {
  description = "Port the container listens on"
  value       = var.container_port
}

output "alb_name" {
  description = "ALB name"
  value       = aws_lb.main.name
}

output "alb_dns_name" {
  description = "ALB DNS name (HTTP endpoint)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID (for a future DNS alias)"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "target_group_blue_arn" {
  description = "Blue target group ARN"
  value       = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  description = "Green target group ARN"
  value       = aws_lb_target_group.green.arn
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.app.name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "task_definition_family" {
  description = "ECS task definition family"
  value       = aws_ecs_task_definition.app.family
}

output "codedeploy_application" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.app.name
}

output "codedeploy_deployment_group" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.app.deployment_group_name
}

output "github_app_role_arn" {
  description = "IAM role assumed by GitHub Actions to build and deploy"
  value       = aws_iam_role.gha_app.arn
}

output "github_terraform_role_arn" {
  description = "IAM role assumed by GitHub Actions to run Terraform"
  value       = aws_iam_role.gha_terraform.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for container logs"
  value       = aws_cloudwatch_log_group.app.name
}

output "cloudwatch_dashboard" {
  description = "CloudWatch dashboard name"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}

output "alarm_topic_arn" {
  description = "SNS topic receiving runtime alarms"
  value       = aws_sns_topic.alarms.arn
}
