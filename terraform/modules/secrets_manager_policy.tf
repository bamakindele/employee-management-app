resource "aws_iam_role_policy" "external_secrets_secrets_manager" {
  name = "read-production-application-secrets"
  role = aws_iam_role.external_secrets.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:GetSecretValue",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = [
        "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:production/postgres-*",
        "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:production/application-*"
      ]
    }]
  })
}