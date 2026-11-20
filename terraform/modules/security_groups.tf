# Restricts PostgreSQL access to the EKS cluster security group.

resource "aws_security_group" "rds" {

  name = "rds-sg"

  vpc_id = aws_vpc.main.id

  ingress {

    from_port = 5432
    to_port   = 5432

    protocol = "tcp"

    security_groups = [
      aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
    ]
  }
}