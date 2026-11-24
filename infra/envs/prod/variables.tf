variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "alarm_emails" {
  description = "Email addresses subscribed to the SNS alarm topic"
  type        = list(string)
  default     = []
}
