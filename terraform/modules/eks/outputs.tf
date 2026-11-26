output "cluster_name" {
  value = aws_eks_cluster.starttech.name
}

output "node_security_group_id" {
  value = local.node_security_group_id
}

output "alb_dns_name" {
  value = aws_lb.backend.dns_name
}
