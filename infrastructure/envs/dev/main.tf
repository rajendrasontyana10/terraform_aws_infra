terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # For dev environment, using local backend
  # To use S3 backend later, create:
  # 1. S3 bucket: terraform-state-dev-rajendra
  # 2. DynamoDB table: terraform-locks with LockID (String) as primary key
  # Then uncomment the backend block below and run: terraform init -migrate-state
  
  # backend "s3" {
  #   bucket         = "terraform-state-dev-rajendra"
  #   key            = "infrastructure/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "vpc" {
  source         = "../../modules/Network"
  vpc_cidr       = "10.0.0.0/16"
  public_subnet  = ["10.0.1.0/24"]
  private_subnet = ["10.0.2.0/24"]
}

module "security_group" {
  source = "../../modules/Security"
  vpc_id = module.vpc.vpc_id
}

module "compute" {
  source    = "../../modules/Compute"
  subnet_id = module.vpc.private_subnet[0]
  sg_id     = module.security_group.sg_id
  ami       = data.aws_ami.amazon_linux.id
}

module "alb" {
  source      = "../../modules/Loadbalancer"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.public_subnet
  alb_sg_id   = module.security_group.alb_sg_id
  instance_id = module.compute.instance_id
}

output "alb_dns_name" {
  description = "DNS name of the ALB"
  value       = module.alb.alb_dns_name
}

output "jenkins_instance_id" {
  description = "Jenkins EC2 instance ID"
  value       = module.compute.jenkins_instance_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}