output "redis_cluster_id" {
  description = "ElastiCache cluster ID."
  value       = aws_elasticache_cluster.starttech_redis.cluster_id
}

output "redis_endpoint" {
  description = "Redis node address (REDIS_HOST for the backend)."
  value       = aws_elasticache_cluster.starttech_redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port."
  value       = aws_elasticache_cluster.starttech_redis.port
}

output "redis_security_group_id" {
  description = "Security group of the Redis cluster."
  value       = aws_security_group.redis.id
}
