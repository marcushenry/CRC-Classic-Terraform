# main.tf

# 1. PROVIDER Configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"             # <-- CHANGE: Set your desired AWS Region
  profile = "dev-terraform"     # <-- CHANGE: Set your active AWS SSO profile name
}

# 2. DATA Source to find the Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2_x86" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # Generic filter for Amazon Linux 2 HVM on x86 architecture (t2/t3)
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] 
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 3. SECURITY GROUP (Firewall)
resource "aws_security_group" "challenge_sg" {
  name        = "http_web_challenge_sg"
  description = "Allow HTTP/HTTPS inbound traffic"

  # INGRESS (Inbound) Rule for HTTP (Port 80)
  ingress {
    description = "HTTP from Public Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  # INGRESS (Inbound) Rule for HTTPS (Port 443)
  ingress {
    description = "HTTPS from Public Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # EGRESS (Outbound) Rule: Allow all traffic out
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. EC2 INSTANCE
resource "aws_instance" "challenge_instance" {
  ami           = data.aws_ami.amazon_linux_2_x86.id
  instance_type = "t2.micro" # <-- FINAL UPDATE: Safest Free Tier choice!
  
  vpc_security_group_ids = [aws_security_group.challenge_sg.id]
  associate_public_ip_address = true 
  
  tags = {
    Name = "My-T2-Micro-EC2-Instance"
  }
}

# 5. OUTPUT
output "public_ip" {
  description = "The Public IP address of the EC2 instance"
  value       = aws_instance.challenge_instance.public_ip
}