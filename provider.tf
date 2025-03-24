provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project = local.lambda_function_name_prefix
    }
  }
}

terraform {
  backend "s3" {
    bucket       = "<myterraformbucket>"
    key          = "<path-to-my-tfstate-file>/terraform.tfstate"
    region       = "ap-southeast-2"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.89.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "2.7.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.2"
    }
  }
  required_version = "1.11"
}
