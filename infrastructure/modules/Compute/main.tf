resource "aws_instance" "app" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.sg_id]

  associate_public_ip_address = false

  tags = {
    Name = "App-Server"
  }
}

resource "aws_instance" "jenkins" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.sg_id]

  associate_public_ip_address = false

  tags = {
    Name   = "Jenkins"
    Server = "Jenkins"
  }

  user_data = file("${path.module}/jenkins_user_data.sh")
}