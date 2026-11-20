output "load_balancer_controller_role_arn" {
  description = "IAM role assumed by the AWS Load Balancer Controller service account."
  value       = aws_iam_role.load_balancer_controller.arn
}
