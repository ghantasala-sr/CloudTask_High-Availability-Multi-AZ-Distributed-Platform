# =============================================================================
# RDS DATABASE
# =============================================================================
# Creates the DB subnet group and RDS MySQL instance.
# In the console this was Phase 3. In Terraform, it's ~30 lines.
# =============================================================================

# DB Subnet Group — tells RDS which subnets to use
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id # [*] means "all items in the list"

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  publicly_accessible = false
  skip_final_snapshot = true # For easy cleanup — don't use in production!

  backup_retention_period = 1 # Free tier allows max 1 day

  tags = { Name = "${var.project_name}-db" }
}
