terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # For production, S3 backend with DynamoDB locking is required
  # Before using this, create:
  # 1. S3 bucket: terraform-state-prod (with versioning enabled)
  # 2. DynamoDB table: terraform-locks with LockID (String) as primary key
  
    #   backend "s3" {
    #     bucket         = "terraform-state-prod"
    #     key            = "infrastructure/terraform.tfstate"
    #     region         = "us-east-1"
    #     encrypt        = true
    #     dynamodb_table = "terraform-locks"
    #   }
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
  vpc_cidr       = "10.1.0.0/16"
  public_subnet  = ["10.1.1.0/24"]
  private_subnet = ["10.1.2.0/24"]
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
  subnet_id   = module.vpc.public_subnet[0]
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
