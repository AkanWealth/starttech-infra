output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = module.storage.ecr_repository_url
}

output "s3_bucket_name" {
  value = module.storage.bucket_name
}

output "cloudfront_distribution_id" {
  value = module.cdn.distribution_id
}

output "cloudfront_domain_name" {
  value = module.cdn.distribution_domain_name
}

output "redis_endpoint" {
  value = module.database.redis_endpoint
}

output "nat_gateway_public_ip" {
  description = "Add to the MongoDB Atlas IP access list."
  value       = module.networking.nat_gateway_public_ip
}
