# Exposes useful resource identifiers and connection information after deployment.
# Add outputs here when other configurations need to consume these values.

output "vpc_id" {
  value = aws_vpc.main.id
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "frontend_ecr" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr" {
  value = aws_ecr_repository.backend.repository_url
}