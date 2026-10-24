# Creates the EKS control plane and a managed node group with two worker nodes.

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id = aws_vpc.main.id

  # The control plane and worker nodes use private subnets.
  subnet_ids = aws_subnet.private[*].id

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Restrict public Kubernetes API access to your IP.
  cluster_endpoint_public_access_cidrs = [
    var.cluster_admin_cidr
  ]

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    workers = {
      name = "learning-workers"

      subnet_ids = aws_subnet.private[*].id

      min_size     = 2
      max_size     = 2
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Name = "learning-eks-cluster"
  }
}
