output "state_bucket_name" {
  description = "S3 bucket used as the Terraform backend for every environment"
  value       = aws_s3_bucket.state.bucket
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}
