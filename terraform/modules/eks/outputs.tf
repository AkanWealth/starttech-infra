output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.starttech.name
}

output "cluster_arn" {
  description = "EKS cluster ARN."
  value       = aws_eks_cluster.starttech.arn
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.starttech.endpoint
}

output "cluster_version" {
  description = "Kubernetes version."
  value       = aws_eks_cluster.starttech.version
}

output "cluster_certificate_authority_data" {
  description = "Base64 cluster CA certificate."
  value       = aws_eks_cluster.starttech.certificate_authority[0].data
}

output "node_group_name" {
  description = "Managed node group name."
  value       = aws_eks_node_group.starttech_node_group.node_group_name
}

output "node_security_group_id" {
  description = "Security group attached to the worker nodes (EKS cluster security group)."
  value       = local.node_security_group_id
}

output "node_role_arn" {
  description = "Worker node IAM role ARN."
  value       = aws_iam_role.node.arn
}

output "alb_dns_name" {
  description = "DNS name of the backend ALB (CloudFront origin ALB-Backend)."
  value       = aws_lb.backend.dns_name
}

output "alb_arn" {
  description = "ARN of the backend ALB."
  value       = aws_lb.backend.arn
}

output "backend_target_group_arn" {
  description = "Target group that receives backend traffic on the NodePort."
  value       = aws_lb_target_group.backend.arn
}
