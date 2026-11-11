# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all regional resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used in tags."
  type        = string
  default     = "production"
}

variable "extra_tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow terraform destroy to remove a non-empty S3 bucket and ECR repository."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for starttech-vpc."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "true: one NAT gateway (cheaper). false: one NAT gateway per AZ (highly available)."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# EKS
# ---------------------------------------------------------------------------

variable "cluster_version" {
  description = "Kubernetes version (1.34 or newer)."
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_type" {
  description = "Worker node instance type."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired worker node count."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum worker node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum worker node count."
  type        = number
  default     = 4
}

variable "backend_node_port" {
  description = "NodePort of the backend-api Service; the ALB targets it. Must match k8s/service.yaml."
  type        = number
  default     = 30080
}

variable "eks_admin_principal_arns" {
  description = "Extra IAM principals (users/roles) to grant EKS cluster admin."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# CDN
# ---------------------------------------------------------------------------

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

# ---------------------------------------------------------------------------
# CI/CD and grading
# ---------------------------------------------------------------------------

variable "github_owner" {
  description = "GitHub user or organization that owns both repositories. Empty skips the GitHub OIDC roles."
  type        = string
  default     = ""
}

variable "infra_repository" {
  description = "Infrastructure repository name."
  type        = string
  default     = "starttech-infra"
}

variable "app_repository" {
  description = "Application repository name."
  type        = string
  default     = "starttech-application"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider (set false if the account already has one)."
  type        = bool
  default     = true
}

variable "create_grader_user" {
  description = "Create the read-only start-tech-grader IAM user."
  type        = bool
  default     = true
}
