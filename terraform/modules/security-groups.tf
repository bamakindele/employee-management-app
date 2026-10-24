# Creates a security group for RDS. 
# PostgreSQL traffic is allowed from the EKS node security group.

resource "aws_security_group" "rds" {
  name_prefix = "learning-rds-"
  description = "Allow PostgreSQL from EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "learning-rds-sg"
  }
}
