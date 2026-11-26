variable "vpc_id" {
  type = string
}

variable "database_subnet_ids" {
  type = list(string)
}

variable "eks_node_security_group_id" {
  type = string
}
