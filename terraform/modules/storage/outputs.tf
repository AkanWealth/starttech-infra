output "bucket_name" {
  description = "Frontend bucket name."
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "Frontend bucket ARN."
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name used as the CloudFront S3 origin."
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "ecr_repository_name" {
  description = "ECR repository name."
  value       = aws_ecr_repository.backend.name
}

output "ecr_repository_url" {
  description = "ECR repository URL."
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_repository_arn" {
  description = "ECR repository ARN."
  value       = aws_ecr_repository.backend.arn
}
