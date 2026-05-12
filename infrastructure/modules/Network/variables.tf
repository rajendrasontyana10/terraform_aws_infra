variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}