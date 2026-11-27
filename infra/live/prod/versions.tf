terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "aws-ecs-bluegreen-tfstate-682227955413"
    key          = "live/prod/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}
