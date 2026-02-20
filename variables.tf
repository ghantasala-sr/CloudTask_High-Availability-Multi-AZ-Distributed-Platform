# =============================================================================
# VARIABLES
# =============================================================================
# Variables let you customize the deployment without changing the main code.
# Think of them as function parameters — you define them here and use them
# throughout other .tf files with var.variable_name
#
# You can override these when running terraform apply:
#   terraform apply -var="db_password=mypassword"
# Or create a terraform.tfvars file with your values.
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "three-tier"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true # This hides the value in terraform output/logs
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "taskdb"
}

variable "instance_type" {
  description = "EC2 instance type for web and app tiers"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}
