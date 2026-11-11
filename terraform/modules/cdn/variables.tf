variable "s3_bucket_id" {
  description = "Frontend bucket name."
  type        = string
}

variable "s3_bucket_arn" {
  description = "Frontend bucket ARN."
  type        = string
}

variable "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the frontend bucket."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the backend ALB."
  type        = string
}

variable "origin_verify_secret" {
  description = "Value of the X-Origin-Verify header sent to the ALB."
  type        = string
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}
