terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "beanstalk-nodejs-app-tfstate-682227955413"
    key          = "envs/dev/terraform.tfstate"
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
