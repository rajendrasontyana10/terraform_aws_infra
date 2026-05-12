# terraform_aws_infra

AWS Infrastructure creation using Terraform with Jenkins automation support.

## Project Overview

This Terraform project deploys a complete AWS infrastructure including:
- **VPC** with public and private subnets
- **Security Groups** for ALB and EC2 instances
- **EC2 Instances** (Application server and Jenkins)
- **Application Load Balancer (ALB)** with target groups
- **NAT Gateway** for private subnet internet access
- **Internet Gateway** for public subnet connectivity

## Project Structure

```
.
├── README.md
├── infrastructure/
│   ├── providers.tf              # AWS provider configuration
│   ├── variables.tf              # Root-level variables
│   ├── envs/
│   │   ├── dev/
│   │   │   ├── main.tf          # Dev environment configuration
│   │   │   └── terraform.tfvars # Dev environment variables
│   │   └── prod/
│   │       ├── main.tf          # Prod environment configuration
│   │       └── terraform.tfvars # Prod environment variables
│   └── modules/
│       ├── Compute/
│       │   ├── main.tf          # EC2 instance resources
│       │   ├── variables.tf
│       │   ├── outputs.tf
│       │   └── jenkins_user_data.sh
│       ├── Network/
│       │   ├── main.tf          # VPC, subnets, NAT, IGW
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── Security/
│       │   ├── main.tf          # Security groups
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── Loadbalancer/
│           ├── main.tf          # ALB and target groups
│           ├── variables.tf
│           └── outputs.tf
└── pipelines/
    └── infra-setup.jenkinsfile  # CI/CD pipeline

```

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- Jenkins (for pipeline execution)
- Git repository access

## Quick Start

### 1. Initialize Terraform

```bash
cd infrastructure
terraform init
```

### 2. Select Environment

```bash
# For dev environment
cd envs/dev

# For prod environment
cd envs/prod
```

### 3. Plan Deployment

```bash
terraform plan -var-file="terraform.tfvars"
```

### 4. Apply Configuration

```bash
terraform apply -var-file="terraform.tfvars"
```

## Environment Configuration

### Development Environment
- VPC CIDR: `10.0.0.0/16`
- Public Subnet: `10.0.1.0/24`
- Private Subnet: `10.0.2.0/24`
- Instance Type: `t2.micro`

### Production Environment
- VPC CIDR: `10.1.0.0/16`
- Public Subnet: `10.1.1.0/24`
- Private Subnet: `10.1.2.0/24`
- Instance Type: `t2.micro`

## Modules

### Network Module
Creates VPC infrastructure including:
- VPC
- Public and private subnets
- Internet Gateway
- NAT Gateway with Elastic IP
- Route tables and associations

**Variables:**
- `vpc_cidr` - CIDR block for VPC
- `public_subnet` - List of public subnet CIDR blocks
- `private_subnet` - List of private subnet CIDR blocks

**Outputs:**
- `vpc_id` - VPC ID
- `public_subnet` - Public subnet IDs
- `private_subnet` - Private subnet IDs

### Security Module
Creates security groups for:
- ALB (Application Load Balancer)
- EC2 instances

**Variables:**
- `vpc_id` - VPC ID for security group placement

**Outputs:**
- `sg_id` - EC2 security group ID
- `alb_sg_id` - ALB security group ID

### Compute Module
Creates EC2 instances:
- Application server
- Jenkins server with automation

**Variables:**
- `ami` - AMI ID for instances
- `subnet_id` - Subnet for instance placement
- `sg_id` - Security group ID

**Outputs:**
- `instance_id` - Application instance ID
- `jenkins_instance_id` - Jenkins instance ID
- `sg_id` - Security group ID

### Loadbalancer Module
Creates Application Load Balancer:
- ALB across public subnets
- Target group for instances
- Health checks

**Variables:**
- `vpc_id` - VPC ID
- `subnet_id` - Public subnet for ALB
- `alb_sg_id` - ALB security group ID
- `instance_id` - Target instance ID

**Outputs:**
- `alb_arn` - ALB ARN
- `alb_dns_name` - ALB DNS name
- `target_group_arn` - Target group ARN

## Jenkins Integration

### Pipeline Configuration

The `infra-setup.jenkinsfile` provides automated deployment with:

**Parameters:**
- `ENV` - Environment selection (dev/prod)
- `AWS_REGION` - AWS region (default: us-east-1)
- `AWS_PROFILE` - AWS CLI profile (default: default)
- `GIT_REPO_URL` - Repository URL
- `BRANCH` - Git branch (main/develop)
- `GIT_CREDENTIALS_ID` - Jenkins Git credentials ID

**Pipeline Stages:**
1. Checkout Code
2. Terraform Init
3. Terraform Validate
4. Terraform Format Check
5. Terraform Plan
6. Manual Approval
7. Terraform Apply
8. Terraform Output

### Jenkins Setup

1. Create a parameterized job
2. Add Git repository
3. Configure Jenkins credentials
4. Add the `infra-setup.jenkinsfile` as pipeline script
5. Run with desired parameters

## Jenkins User Data Script

The `jenkins_user_data.sh` script automatically:
- Updates system packages
- Installs Java 21 (Amazon Corretto)
- Installs Jenkins
- Configures Jenkins to use Java 21
- Starts Jenkins service

## Backend State Management

For production deployments, configure S3 backend:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-prod"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Prerequisites:**
- S3 bucket for state storage
- DynamoDB table for state locking
- Appropriate IAM permissions

## Outputs

After applying Terraform, the following outputs are available:

```
alb_dns_name       - DNS name to access the application
jenkins_instance_id - Jenkins server instance ID
vpc_id             - VPC identifier
```

## Security Best Practices

- ✅ Private subnets for application servers
- ✅ NAT Gateway for private subnet egress
- ✅ Security groups with restricted access
- ✅ State file encryption (S3 backend)
- ✅ State locking (DynamoDB)

## Cleanup

To destroy all resources:

```bash
cd infrastructure/envs/{environment}
terraform destroy -var-file="terraform.tfvars"
```

## Troubleshooting

### AMI not found
- Verify the AWS region matches the filter
- Check Amazon Linux 2 availability in your region

### Terraform state lock
- Check DynamoDB table has correct permissions
- Ensure S3 bucket versioning is enabled

### Jenkins user data errors
- Check EC2 instance system logs
- Verify Java 21 installation: `/opt/java21/bin/java -version`

## Contributing

1. Create a feature branch
2. Make changes
3. Test with `terraform plan`
4. Commit and push
5. Create pull request

## Support

For issues or questions, refer to:
- Terraform Documentation: https://www.terraform.io/docs/
- AWS Provider Documentation: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Jenkins Documentation: https://www.jenkins.io/doc/

## License

This project is provided as-is for infrastructure automation purposes.
