output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_azs" {
  description = "Availability zones of public subnets"
  value       = aws_subnet.public[*].availability_zone
}