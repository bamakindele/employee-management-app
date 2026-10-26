# Creates the managed worker group in the private subnets.
# Move scaling limits and instance types to variables to reuse across environments.
resource "aws_eks_node_group" "main" {

  cluster_name = aws_eks_cluster.main.name

  node_group_name = "worker-group"

  node_role_arn = aws_iam_role.node_role.arn

  subnet_ids = [

    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  scaling_config {

    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  instance_types = [
    "t3.medium"
  ]
}