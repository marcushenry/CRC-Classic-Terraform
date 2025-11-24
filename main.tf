# main.tf

# 1. PROVIDER Configuration (UNCHANGED)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "dev-terraform"
}

# --- CUSTOM CONFIGURATION ---
locals {
  # Your Route 53 Hosted Zone ID (Confirmed: Z0188629LIZ3QYKWOH6U)
  hosted_zone_id = "Z0188629LIZ3QYKWOH6U"
  # The Public HTTPS URL for your resume PDF
  resume_s3_url  = "https://marcushenrycloudopsresume.s3.us-east-1.amazonaws.com/Marcus-Henry-Resume.pdf"
  # The full subdomain you want to use
  domain_name    = "resume.marcushenry.ca"
}

# 2. DATA Source to find the Amazon Linux 2 AMI (UNCHANGED)
data "aws_ami" "amazon_linux_2_x86" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"] 
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- VPC AND NETWORKING COMPONENTS (Simplified for Public Access) ---

# 3. CUSTOM VPC AND SUBNETS

# A. VPC (The Network Container)
resource "aws_vpc" "challenge_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "Challenge-VPC"
  }
}

# B. INTERNET GATEWAY (For the Public Subnet)
resource "aws_internet_gateway" "challenge_igw" {
  vpc_id = aws_vpc.challenge_vpc.id
  tags = {
    Name = "Challenge-IGW"
  }
}

# E. PUBLIC SUBNET (For Internet-facing resources like your Web Server)
resource "aws_subnet" "challenge_public_subnet" {
  vpc_id                  = aws_vpc.challenge_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true 
  availability_zone       = "us-east-1a" 

  tags = {
    Name = "Challenge-Public-Subnet-A"
  }
}

# F. PRIVATE SUBNET ( kept for structure, but unused for the instance )
resource "aws_subnet" "challenge_private_subnet" {
  vpc_id                  = aws_vpc.challenge_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false 
  availability_zone       = "us-east-1a" 

  tags = {
    Name = "Challenge-Private-Subnet-A"
  }
}

# G. PUBLIC ROUTE TABLE (Routes to IGW)
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.challenge_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.challenge_igw.id
  }
  tags = {
    Name = "Public-Route-Table"
  }
}

# I. ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.challenge_public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# --- END NETWORKING COMPONENTS ---


# 4. SECURITY GROUP (Firewall)
resource "aws_security_group" "challenge_sg" {
  name        = "http_web_challenge_sg"
  description = "Allow HTTP/HTTPS/SSH inbound traffic"
  vpc_id      = aws_vpc.challenge_vpc.id

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
  
  # SSH Rule for Administration
  ingress { 
    description = "SSH from Public Internet"
    from_port   = 22
    to_port     = 22
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


# 5. EC2 INSTANCE
resource "aws_instance" "challenge_instance" {
  ami             = data.aws_ami.amazon_linux_2_x86.id
  instance_type   = "t2.micro" 
  
  vpc_security_group_ids = [aws_security_group.challenge_sg.id]
  associate_public_ip_address = true 
  
  # **[UPDATE]** Instance now launches in the new PUBLIC subnet (No NAT needed)
  subnet_id = aws_subnet.challenge_public_subnet.id
  
  # **[ADDED]** User Data to ensure Apache is installed and Redirect is set up
  user_data = base64encode(<<-EOF
    #!/bin/bash
    S3_URL="${local.resume_s3_url}"
    
    sudo yum update -y
    sudo yum install httpd -y
    sudo systemctl start httpd
    sudo systemctl enable httpd
    
    # Create the redirect HTML file
    sudo cat > /var/www/html/index.html <<-EOF_HTML
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; URL=$${S3_URL}">
    <title>Redirecting to Resume...</title>
</head>
<body>
    <h1>Redirecting to Marcus Henry's Resume...</h1>
    <p>If you are not redirected automatically, follow this <a href="$${S3_URL}">link to the resume</a>.</p>
</body>
</html>
EOF_HTML
    EOF
  )
  
  tags = {
    Name = "Custom-VPC-Web-Instance"
  }
}

# 6. ROUTE 53 DNS RECORD (New Resource)
resource "aws_route53_record" "challenge_a_record" {
  zone_id = local.hosted_zone_id
  name    = local.domain_name 
  type    = "A"
  ttl     = 300
  records = [aws_instance.challenge_instance.public_ip]
}

# 7. OUTPUT
output "public_ip" {
  description = "The Public IP address of the EC2 instance"
  value       = aws_instance.challenge_instance.public_ip
}

output "resume_url" {
  description = "The custom domain URL for the resume"
  value       = "http://${local.domain_name}"
}