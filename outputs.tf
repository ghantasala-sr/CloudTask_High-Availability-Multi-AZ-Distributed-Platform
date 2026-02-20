# =============================================================================
# OUTPUTS
# =============================================================================
# Outputs are values Terraform prints after deployment.
# Think of them as return values — they tell you what was created.
#
# After `terraform apply`, you'll see:
#   app_url = "http://three-tier-ext-alb-123456.us-east-1.elb.amazonaws.com"
# =============================================================================

output "app_url" {
  description = "URL to access the Task Manager application"
  value       = "http://${aws_lb.external.dns_name}"
}

output "external_alb_dns" {
  description = "External ALB DNS name"
  value       = aws_lb.external.dns_name
}

output "internal_alb_dns" {
  description = "Internal ALB DNS name"
  value       = aws_lb.internal.dns_name
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.main.address
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}
