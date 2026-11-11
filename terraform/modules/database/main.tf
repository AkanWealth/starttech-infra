# Single-node Redis (ElastiCache) in the private database subnets.
# Only the EKS worker nodes can connect.

resource "aws_elasticache_subnet_group" "redis" {
  name        = "starttech-redis-subnet-group"
  description = "Private database subnets for starttech-redis"
  subnet_ids  = var.database_subnet_ids
}

resource "aws_security_group" "redis" {
  name        = "starttech-redis-sg"
  description = "starttech-redis: Redis from EKS worker nodes only"
  vpc_id      = var.vpc_id

  tags = {
    Name = "starttech-redis-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_eks_nodes" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from EKS worker nodes"
  referenced_security_group_id = var.eks_node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

resource "aws_elasticache_cluster" "starttech_redis" {
  cluster_id           = "starttech-redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = var.parameter_group_name

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]

  snapshot_retention_limit = var.snapshot_retention_limit
  maintenance_window       = "sun:03:00-sun:04:00"
  apply_immediately        = true

  tags = {
    Name = "starttech-redis"
  }
}
