data "aws_iam_role" "external_secrets" {
  name = "external-secrets-secrets-manager"
}

data "aws_iam_policy_document" "load_balancer_controller_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

data "http" "load_balancer_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.6.3/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "load_balancer_controller" {
  name        = "devops-cluster-aws-load-balancer-controller"
  description = "Permissions for the AWS Load Balancer Controller on devops-cluster."
  policy      = data.http.load_balancer_controller_policy.response_body
}

resource "aws_iam_role" "load_balancer_controller" {
  name               = "devops-cluster-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.load_balancer_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.15.0"
  namespace        = "external-secrets"
  create_namespace = true
  wait             = true
  timeout          = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = data.aws_iam_role.external_secrets.arn
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.6.3"
  namespace  = "kube-system"
  wait       = true
  timeout    = 600

  set {
    name  = "clusterName"
    value = data.aws_eks_cluster.main.name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = data.aws_eks_cluster.main.vpc_config[0].vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.load_balancer_controller.arn
  }

  depends_on = [
    aws_iam_role_policy_attachment.load_balancer_controller,
  ]
}
