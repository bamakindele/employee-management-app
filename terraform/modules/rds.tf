# Creates the database subnet group and PostgreSQL RDS instance.

resource "aws_db_subnet_group" "main" {
  name       = "learning-rds-subnets"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "learning-rds-subnets"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "learning-eks-postgres"

  engine         = "postgres"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = "dbadmin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible = false
  multi_az             = false

  backup_retention_period = 1
  auto_minor_version_upgrade = true

  # Learning environment only.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name = "learning-eks-postgres"
  }
}
