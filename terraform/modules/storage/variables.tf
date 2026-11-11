variable "force_destroy" {
  description = "Allow terraform destroy to delete a non-empty bucket and ECR repository."
  type        = bool
  default     = true
}
