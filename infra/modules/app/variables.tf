variable "app_name" {
  description = "Application name, used as the prefix of every resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.app_name))
    error_message = "app_name must be 3-31 characters, lowercase alphanumeric or hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,10}$", var.environment))
    error_message = "environment must be 2-11 characters, lowercase alphanumeric or hyphens."
  }
}

variable "state_bucket_name" {
  description = "S3 bucket holding Terraform state (used to scope the CI Terraform role)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  default     = 8080
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial desired number of tasks (auto scaling owns it afterwards)"
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Minimum tasks for auto scaling"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum tasks for auto scaling"
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "Bootstrap image tag used before CI deploys the first digest"
  type        = string
  default     = "bootstrap"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for container logs"
  type        = number
  default     = 30
}

variable "deployment_config_name" {
  description = "CodeDeploy ECS deployment configuration (traffic shifting)"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"

  validation {
    condition = contains(
      [
        "CodeDeployDefault.ECSAllAtOnce",
        "CodeDeployDefault.ECSLinear10PercentEvery1Minutes",
        "CodeDeployDefault.ECSLinear10PercentEvery3Minutes",
        "CodeDeployDefault.ECSCanary10Percent5Minutes",
        "CodeDeployDefault.ECSCanary10Percent15Minutes",
      ],
      var.deployment_config_name,
    )
    error_message = "deployment_config_name must be a predefined ECS CodeDeploy deployment configuration."
  }
}

variable "blue_termination_wait_minutes" {
  description = "How long the previous task set is kept after a successful deployment"
  type        = number
  default     = 0
}

variable "enable_deletion_protection" {
  description = "Enable ALB deletion protection"
  type        = bool
  default     = false
}

variable "ecr_force_delete" {
  description = "Allow Terraform to delete the ECR repository even when it contains images"
  type        = bool
  default     = false
}

variable "alarm_emails" {
  description = "Email addresses subscribed to the SNS alarm topic"
  type        = list(string)
  default     = []
}

variable "alarm_5xx_threshold" {
  description = "Number of 5xx responses per minute (2 periods) before alarming"
  type        = number
  default     = 5
}

variable "alarm_latency_p95_seconds" {
  description = "p95 target response time in seconds (3 periods) before alarming"
  type        = number
  default     = 1
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider (created by infra/bootstrap)"
  type        = string
}

variable "github_subject_claims" {
  description = "Allowed token.actions.githubusercontent.com:sub claims for the CI roles"
  type        = list(string)

  validation {
    condition     = length(var.github_subject_claims) > 0
    error_message = "At least one GitHub OIDC subject claim is required."
  }
}

variable "tags" {
  description = "Additional tags applied to every resource"
  type        = map(string)
  default     = {}
}
