output "aws_region" {
  description = "AWS region."
  value       = var.aws_region
}

output "vpc_id" {
  description = "starttech-vpc ID."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes)."
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Egress IPs of the cluster. Add these to the MongoDB Atlas IP access list."
  value       = module.networking.nat_gateway_public_ips
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  description = "EKS managed node group name."
  value       = module.eks.node_group_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "alb_dns_name" {
  description = "Backend ALB DNS name (only reachable through CloudFront)."
  value       = module.eks.alb_dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for the backend image."
  value       = module.storage.ecr_repository_url
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name (repository variable S3_BUCKET)."
  value       = module.storage.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (repository variable CLOUDFRONT_DISTRIBUTION_ID)."
  value       = module.cdn.distribution_id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name (repository variable CLOUDFRONT_DOMAIN)."
  value       = module.cdn.distribution_domain_name
}

output "application_url" {
  description = "Public URL of the application."
  value       = "https://${module.cdn.distribution_domain_name}"
}

output "redis_endpoint" {
  description = "ElastiCache Redis address (REDIS_HOST)."
  value       = module.database.redis_endpoint
}

output "github_infra_role_arn" {
  description = "Set as secret AWS_ROLE_ARN in the starttech-infra repository."
  value       = module.iam.github_infra_role_arn
}

output "github_app_role_arn" {
  description = "Set as secret AWS_ROLE_ARN in the starttech-application repository."
  value       = module.iam.github_app_role_arn
}

output "grader_user_name" {
  description = "Read-only grader IAM user."
  value       = module.iam.grader_user_name
}
