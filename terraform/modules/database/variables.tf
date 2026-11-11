variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "database_subnet_ids" {
  description = "Private database subnet IDs."
  type        = list(string)
}

variable "eks_node_security_group_id" {
  description = "Security group of the EKS worker nodes (the only allowed clients)."
  type        = string
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "parameter_group_name" {
  description = "ElastiCache parameter group."
  type        = string
  default     = "default.redis7"
}

variable "snapshot_retention_limit" {
  description = "Days of automatic snapshots to keep (0 disables them)."
  type        = number
  default     = 1
}
