terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.region
}

### VPC default existente
data "aws_vpc" "default" {
  default = true
}

### AMI de Ubuntu 24.04 más reciente (publicada por Canonical)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

### Llave SSH generada por Terraform
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "todo_key" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.ssh.public_key_openssh
}

### Security Group: SSH + puerto de la API
resource "aws_security_group" "todo_sg" {
  name   = "${var.project_name}-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "API to-do list"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Instancia EC2 con la app desplegada vía user_data
resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.todo_key.key_name
  vpc_security_group_ids      = [aws_security_group.todo_sg.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url = var.repo_url
    app_port = var.app_port
  })
  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-server"
  }
}