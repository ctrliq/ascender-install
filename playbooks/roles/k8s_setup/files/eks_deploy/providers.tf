terraform {
  required_version = ">=1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}

provider "aws" {
  region = var.region
}