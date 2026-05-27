terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "my-lightsail-proxy-terraform-state"
    key     = "lightsail-proxy/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region                   = var.regions[var.selected_country]
  profile                  = var.aws_profile
  shared_config_files      = [var.aws_conf_file_path]
  shared_credentials_files = [var.aws_cred_file_path]
}
