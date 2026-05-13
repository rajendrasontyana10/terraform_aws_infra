resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Explicitly use the specified AZs for multi-AZ deployment
locals {
  azs = ["us-east-1a", "us-east-1b"]
  
  # Map subnets to specific AZs
  public_az_1  = local.azs[0]   # us-east-1a
  public_az_2  = local.azs[1]   # us-east-1b
  private_az_1 = local.azs[0]   # us-east-1a
  private_az_2 = local.azs[1]   # us-east-1b
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet[count.index]
  availability_zone       = count.index == 0 ? local.public_az_1 : local.public_az_2
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}-${count.index == 0 ? local.public_az_1 : local.public_az_2}"
  }
}

resource "aws_subnet" "private" {
  count              = length(var.private_subnet)
  vpc_id             = aws_vpc.main.id
  cidr_block         = var.private_subnet[count.index]
  availability_zone  = count.index == 0 ? local.private_az_1 : local.private_az_2

  tags = {
    Name = "private-subnet-${count.index + 1}-${count.index == 0 ? local.private_az_1 : local.private_az_2}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_eip" "nat" {
  count   = length(var.public_subnet)
  domain  = "vpc"

  tags = {
    Name = "nat-eip-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  count             = length(var.public_subnet)
  allocation_id     = aws_eip.nat[count.index].id
  subnet_id         = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gateway-${count.index + 1}"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count          = length(var.private_subnet)
  vpc_id         = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index % length(aws_nat_gateway.nat)].id
  }

  tags = {
    Name = "private-rt-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# VPC Endpoints for SSM (Systems Manager)
# This allows EC2 instances in private subnets to connect to SSM without NAT Gateway
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]

  tags = {
    Name = "ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]

  tags = {
    Name = "ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpce_sg.id]

  tags = {
    Name = "ec2messages-endpoint"
  }
}

# Security group for VPC Endpoints
resource "aws_security_group" "vpce_sg" {
  vpc_id = aws_vpc.main.id
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpce-sg"
  }
}

# Data source to get current region
data "aws_region" "current" {}