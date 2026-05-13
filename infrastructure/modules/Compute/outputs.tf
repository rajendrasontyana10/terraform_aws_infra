output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "sg_id" {
  value = var.sg_id
}

output "iam_role_arn" {
  description = "IAM role ARN for EC2 instances"
  value       = aws_iam_role.ec2_role.arn
}

output "instance_profile_name" {
  description = "Instance profile name"
  value       = aws_iam_instance_profile.ec2_profile.name
}