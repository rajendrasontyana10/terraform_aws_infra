output "instance_id" {
  value = aws_instance.app.id
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "sg_id" {
  value = var.sg_id
}