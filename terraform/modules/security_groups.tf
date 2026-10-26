# Creates security groups for EKS nodes and RDS.
# PostgreSQL ingress is restricted to the EKS node security group.

resource "aws_security_group" "eks_nodes" {

  name   = "eks-nodes"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds" {

  name = "rds-sg"

  vpc_id = aws_vpc.main.id

  ingress {

    from_port = 5432
    to_port   = 5432

    protocol = "tcp"

    security_groups = [
      aws_security_group.eks_nodes.id
    ]
  }
}