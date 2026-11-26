terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # bucket and region are passed at init time (see scripts/deploy-infrastructure.sh).
  backend "s3" {
    key          = "starttech/infrastructure.tfstate"
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr = var.vpc_cidr
}

module "eks" {
  source = "./modules/eks"

  cluster_version    = var.cluster_version
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
}

module "storage" {
  source = "./modules/storage"
}

module "database" {
  source = "./modules/database"

  vpc_id                     = module.networking.vpc_id
  database_subnet_ids        = module.networking.database_subnet_ids
  eks_node_security_group_id = module.eks.node_security_group_id
}

module "cdn" {
  source = "./modules/cdn"

  s3_bucket_id                   = module.storage.bucket_name
  s3_bucket_arn                  = module.storage.bucket_arn
  s3_bucket_regional_domain_name = module.storage.bucket_regional_domain_name
  alb_dns_name                   = module.eks.alb_dns_name
}

# Read-only grader user
resource "aws_iam_user" "grader" {
  name          = "start-tech-grader"
  force_destroy = true
}

resource "aws_iam_user_policy" "grader" {
  name = "start-tech-grader-read-only"
  user = aws_iam_user.grader.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "GraderReadOnlyS3"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets", "s3:GetBucketPublicAccessBlock", "s3:ListBucket"]
        Resource = "*"
      },
      {
        Sid      = "GraderReadOnlyCloudFront"
        Effect   = "Allow"
        Action   = ["cloudfront:ListDistributions", "cloudfront:GetDistributionConfig"]
        Resource = "*"
      },
      {
        Sid      = "GraderReadOnlyEKS"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListNodegroups", "eks:DescribeNodegroup"]
        Resource = "*"
      },
      {
        Sid      = "GraderReadOnlyElastiCache"
        Effect   = "Allow"
        Action   = ["elasticache:DescribeCacheClusters"]
        Resource = "*"
      },
    ]
  })
}
