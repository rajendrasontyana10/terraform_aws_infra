data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]

  filter {
  name = "name"
  values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

module "vpc" {
  source = "../../modules/Network"
  vpc_cidr = "10.0.0.0/16"
  public_subnet = ["10.0.1.0/24"]
  private_subnet = ["10.0.2.0/24"]
}

module "security_group" {
  source = "../../modules/Security"
  vpc_id = module.vpc.vpc_id
}

module "alb" {
  source = "../../modules/Loadbalancer"
  vpc_id = module.vpc.vpc_id
  subnet_id   = module.vpc.public_subnet[0]
  sg_id       = module.compute.sg_id
  instance_id = module.compute.instance_id
}

module "compute" {
  source = "../../modules/Compute"
  subnet_id = module.vpc.private_subnet[0]
  sg_id     = module.security_group.sg_id
  ami       = data.aws_ami.amazon_linux.id
}