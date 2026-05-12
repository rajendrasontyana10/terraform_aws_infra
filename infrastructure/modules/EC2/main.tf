resource "aws_instance" "app1" {
  ami           = var.ami
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.sg_id]

  associate_public_ip_address = false
}

resource "aws_instance" "jenkins-ec2" {
  instance_type = "t2.micro"
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [var.sg_id]

  associate_public_ip_address = false

  tags = {
    "Name" = "Jenkins"
    "Server" = "Jenkins"
    "AZ" = "useast-1"
  }

  user_data = abs(file("./jenkins_user_data.sh"))
}