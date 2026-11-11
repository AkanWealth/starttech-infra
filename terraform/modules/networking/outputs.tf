output "vpc_id" {
  description = "ID of the starttech-vpc VPC."
  value       = aws_vpc.starttech_vpc.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.starttech_vpc.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB, NAT gateways)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS worker nodes)."
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Private database subnet IDs (ElastiCache)."
  value       = aws_subnet.database[*].id
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT gateways (egress IPs to allow-list in MongoDB Atlas)."
  value       = aws_eip.nat[*].public_ip
}

output "availability_zones" {
  description = "Availability zones in use."
  value       = local.azs
}
