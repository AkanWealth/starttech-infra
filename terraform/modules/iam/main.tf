# IAM for automation and grading:
#   - GitHub Actions OIDC roles (no long-lived AWS keys in GitHub)
#   - The read-only start-tech-grader user

data "aws_partition" "current" {}

locals {
  github_enabled = var.github_owner != ""
  oidc_url       = "token.actions.githubusercontent.com"
  oidc_provider_arn = local.github_enabled ? (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  ) : ""
}

# ---------------------------------------------------------------------------
# GitHub OIDC provider
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  count = local.github_enabled && var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = local.github_enabled && !var.create_github_oidc_provider ? 1 : 0
  url   = "https://${local.oidc_url}"
}

# Trust only the main branch and the "production" environment of one repo.
data "aws_iam_policy_document" "github_trust" {
  for_each = local.github_enabled ? {
    infra = var.infra_repository
    app   = var.app_repository
  } : {}

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "${local.oidc_url}:sub"
      values = [
        "repo:${var.github_owner}/${each.value}:ref:refs/heads/main",
        "repo:${var.github_owner}/${each.value}:environment:production",
      ]
    }
  }
}

# ---------------------------------------------------------------------------
# Infrastructure pipeline role (starttech-infra)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "github_infra" {
  count = local.github_enabled ? 1 : 0

  name                 = "starttech-github-infra-deploy"
  description          = "Assumed by the starttech-infra GitHub Actions workflow to run Terraform"
  assume_role_policy   = data.aws_iam_policy_document.github_trust["infra"].json
  max_session_duration = 7200
}

# Terraform creates VPCs, EKS, IAM roles, CloudFront and more, so this role
# needs broad rights. The trust policy limits it to the main branch.
resource "aws_iam_role_policy_attachment" "github_infra_admin" {
  count = local.github_enabled ? 1 : 0

  role       = aws_iam_role.github_infra[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------
# Application pipeline role (starttech-application)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "github_app" {
  count = local.github_enabled ? 1 : 0

  name               = "starttech-github-app-deploy"
  description        = "Assumed by the starttech-application GitHub Actions workflows"
  assume_role_policy = data.aws_iam_policy_document.github_trust["app"].json
}

data "aws_iam_policy_document" "github_app" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:DescribeRepositories",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "FrontendBucketList"
    actions   = ["s3:ListBucket"]
    resources = [var.frontend_bucket_arn]
  }

  statement {
    sid       = "FrontendBucketObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.frontend_bucket_arn}/*"]
  }

  statement {
    sid       = "CloudFrontInvalidate"
    actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation", "cloudfront:GetDistribution"]
    resources = [var.cloudfront_distribution_arn]
  }

  # Read-only lookups the workflows use to find resources by name.
  statement {
    sid = "Discovery"
    actions = [
      "cloudfront:ListDistributions",
      "elasticache:DescribeCacheClusters",
      "s3:ListAllMyBuckets",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EksDescribe"
    actions   = ["eks:DescribeCluster"]
    resources = [var.eks_cluster_arn]
  }
}

resource "aws_iam_role_policy" "github_app" {
  count = local.github_enabled ? 1 : 0

  name   = "starttech-app-deploy"
  role   = aws_iam_role.github_app[0].id
  policy = data.aws_iam_policy_document.github_app.json
}

# Kubernetes access for the application pipeline. Cluster scope is needed
# because the pipeline creates the starttech namespace.
resource "aws_eks_access_entry" "github_app" {
  count = local.github_enabled ? 1 : 0

  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_app[0].arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github_app" {
  count = local.github_enabled ? 1 : 0

  cluster_name  = var.eks_cluster_name
  principal_arn = aws_iam_role.github_app[0].arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github_app]
}

# Optional extra cluster admins (for example your own IAM user or SSO role).
resource "aws_eks_access_entry" "admins" {
  for_each = toset(var.eks_admin_principal_arns)

  cluster_name  = var.eks_cluster_name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(var.eks_admin_principal_arns)

  cluster_name  = var.eks_cluster_name
  principal_arn = each.value
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admins]
}

# ---------------------------------------------------------------------------
# Grader user (read-only)
# ---------------------------------------------------------------------------
# Terraform creates the user and its policy only. The console password and
# access key are created out of band with
#   ./scripts/deploy-infrastructure.sh grader-credentials
# so the secrets never land in Terraform state.

resource "aws_iam_user" "grader" {
  count = var.create_grader_user ? 1 : 0

  name          = "start-tech-grader"
  force_destroy = true

  tags = {
    Purpose = "Read-only access for automated grading"
  }
}

resource "aws_iam_user_policy" "grader" {
  count = var.create_grader_user ? 1 : 0

  name   = "start-tech-grader-read-only"
  user   = aws_iam_user.grader[0].name
  policy = file("${path.module}/grader-policy.json")
}
