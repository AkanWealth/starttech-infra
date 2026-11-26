resource "aws_elasticache_subnet_group" "redis" {
  name       = "starttech-redis-subnet-group"
  subnet_ids = var.database_subnet_ids
}

# Allows Redis traffic from the EKS worker nodes only.
resource "aws_security_group" "redis" {
  name   = "starttech-redis-sg"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_eks_nodes" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = var.eks_node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
}

resource "aws_elasticache_cluster" "starttech_redis" {
  cluster_id         = "starttech-redis"
  engine             = "redis"
  node_type          = "cache.t3.micro"
  num_cache_nodes    = 1
  port               = 6379
  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.redis.id]
}
