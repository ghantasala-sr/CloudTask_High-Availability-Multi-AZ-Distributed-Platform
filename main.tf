# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================
# This tells Terraform:
#   1. Which cloud provider to use (AWS)
#   2. Which region to deploy in
#   3. Which version of the AWS provider plugin to download
#
# "provider" is like importing a library — it gives Terraform the ability
# to create AWS resources.
# =============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Use AWS provider version 5.x
    }
  }
}

provider "aws" {
  region = var.aws_region # References the variable from variables.tf

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

# =============================================================================
# DATA SOURCES
# =============================================================================
# Data sources let you READ information from AWS without creating anything.
# Here we're fetching the list of available AZs in our region.
# This is better than hardcoding "us-east-1a" because it works in any region.
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# Get the latest Amazon Linux 2023 AMI automatically
# No more hardcoding AMI IDs that change over time!
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
