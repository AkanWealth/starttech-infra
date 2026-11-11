# StartTech platform: VPC, EKS, S3 + CloudFront, ECR and ElastiCache Redis.
#
#   Browser --HTTPS--> CloudFront --+-- *       --> S3-Frontend (private bucket, OAC)
#                                   +-- /api/*  --> ALB-Backend --> EKS NodePort --> Go API
#                                                                        |
#                                                                        +--> ElastiCache Redis

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state. bucket and region are passed at init time:
  #   terraform init -backend-config="bucket=<state bucket>" -backend-config="region=<region>"
  # scripts/deploy-infrastructure.sh creates the bucket and runs init.
  backend "s3" {
    key          = "starttech/infrastructure.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  project      = "starttech"
  cluster_name = "starttech-cluster"

  common_tags = merge(
    {
      Project     = local.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "starttech-infra"
    },
    var.extra_tags,
  )
}

# Shared secret between CloudFront and the ALB (X-Origin-Verify header).
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

module "networking" {
  source = "./modules/networking"

  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway
  cluster_name       = local.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_version                      = var.cluster_version
  vpc_id                               = module.networking.vpc_id
  private_subnet_ids                   = module.networking.private_subnet_ids
  public_subnet_ids                    = module.networking.public_subnet_ids
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  backend_node_port    = var.backend_node_port
  origin_verify_secret = random_password.origin_verify.result
}

module "storage" {
  source = "./modules/storage"

  force_destroy = var.force_destroy
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
  origin_verify_secret           = random_password.origin_verify.result
  price_class                    = var.cloudfront_price_class
}

module "iam" {
  source = "./modules/iam"

  github_owner                = var.github_owner
  infra_repository            = var.infra_repository
  app_repository              = var.app_repository
  create_github_oidc_provider = var.create_github_oidc_provider

  eks_cluster_name            = module.eks.cluster_name
  eks_cluster_arn             = module.eks.cluster_arn
  ecr_repository_arn          = module.storage.ecr_repository_arn
  frontend_bucket_arn         = module.storage.bucket_arn
  cloudfront_distribution_arn = module.cdn.distribution_arn
  eks_admin_principal_arns    = var.eks_admin_principal_arns
  create_grader_user          = var.create_grader_user
}
