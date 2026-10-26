# Creates the EKS control plane and attaches it to the public and private subnets.
# The worker group is defined separately in eks_node_group.tf.

resource "aws_eks_cluster" "main" {

  name = "devops-cluster"

  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {

    subnet_ids = [

      aws_subnet.private_a.id,
      aws_subnet.private_b.id,

      aws_subnet.public_a.id,
      aws_subnet.public_b.id

    ]
  }
}