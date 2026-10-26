# Creates the private PostgreSQL RDS instance using the subnet group and security group.
# Credentials are inputs; never hard-code database secrets in this file.

resource "aws_db_instance" "postgres" {

  identifier = "postgres-db"

  engine = "postgres"

  engine_version = "15"

  instance_class = "db.t3.micro"

  allocated_storage = 20

  username = var.db_username

  password = var.db_password

  db_subnet_group_name = aws_db_subnet_group.main.name

  vpc_security_group_ids = [
    aws_security_group.rds.id
  ]

  publicly_accessible = false

  skip_final_snapshot = true
}