variable "github_owner" {
  description = "GitHub user or organization that owns the repositories. Empty disables the GitHub OIDC roles."
  type        = string
  default     = ""
}

variable "infra_repository" {
  description = "Name of the infrastructure repository."
  type        = string
  default     = "starttech-infra"
}

variable "app_repository" {
  description = "Name of the application repository."
  type        = string
  default     = "starttech-application"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one."
  type        = bool
  default     = true
}

variable "eks_cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "eks_cluster_arn" {
  description = "EKS cluster ARN."
  type        = string
}

variable "ecr_repository_arn" {
  description = "Backend ECR repository ARN."
  type        = string
}

variable "frontend_bucket_arn" {
  description = "Frontend bucket ARN."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN."
  type        = string
}

variable "eks_admin_principal_arns" {
  description = "Extra IAM principal ARNs to grant EKS cluster admin."
  type        = list(string)
  default     = []
}

variable "create_grader_user" {
  description = "Create the read-only start-tech-grader IAM user."
  type        = bool
  default     = true
}
