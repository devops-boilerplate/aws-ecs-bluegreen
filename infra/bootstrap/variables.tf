variable "aws_region" {
  description = "AWS region for the Terraform state bucket and the GitHub OIDC provider"
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket holding Terraform state. Defaults to beanstalk-nodejs-app-tfstate-<account-id>."
  type        = string
  default     = ""
}
