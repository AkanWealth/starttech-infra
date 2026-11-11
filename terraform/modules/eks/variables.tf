variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane (1.34 or newer)."
  type        = string
  default     = "1.35"

  validation {
    condition     = tonumber(split(".", var.cluster_version)[1]) >= 34
    error_message = "cluster_version must be 1.34 or newer."
  }
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the control plane ENIs and worker nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnets for the backend ALB."
  type        = list(string)
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public Kubernetes API endpoint (GitHub-hosted runners need it open)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2

  validation {
    condition     = var.node_min_size >= 2
    error_message = "The node group must keep at least 2 instances."
  }
}

variable "node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Root volume size (GiB) for worker nodes."
  type        = number
  default     = 20
}

variable "log_retention_days" {
  description = "Retention for EKS control plane logs."
  type        = number
  default     = 30
}

variable "backend_node_port" {
  description = "NodePort exposed by the backend-api Service (must match k8s/service.yaml)."
  type        = number
  default     = 30080

  validation {
    condition     = var.backend_node_port >= 30000 && var.backend_node_port <= 32767
    error_message = "backend_node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "origin_verify_secret" {
  description = "Shared secret CloudFront sends in X-Origin-Verify; the ALB only forwards requests that carry it."
  type        = string
  sensitive   = true
}
