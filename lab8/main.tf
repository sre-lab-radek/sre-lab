terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

data "aws_caller_identity" "me" {}

output "account_id" {
  value = data.aws_caller_identity.me.account_id
}

resource "aws_vpc" "lab" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "sre-lab-v2"
  }
}

output "vpc_id" {
  value = aws_vpc.lab.id
}
