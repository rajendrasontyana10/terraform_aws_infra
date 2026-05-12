variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where EC2 instances will be launched"
  type        = string
}

variable "sg_id" {
  description = "Security group ID for EC2 instances"
  type        = string
}