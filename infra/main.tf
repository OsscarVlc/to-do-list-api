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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

### Security Group de la EC2: SSH + puerto de la API
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

### Security Group de RDS: solo acepta conexiones que vengan de la EC2
resource "aws_security_group" "db_sg" {
  name   = "${var.project_name}-db-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description     = "PostgreSQL desde la EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.todo_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

### Contraseña de la BD generada por Terraform
resource "random_password" "db" {
  length           = 20
  special          = true
  override_special = "!#$%^&*()-_=+"
}

### Base de datos PostgreSQL en RDS
resource "aws_db_instance" "db" {
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  instance_class         = var.db_instance_class
  allocated_storage      = 20
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db.result
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
}

### Secreto con los datos de conexión
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.project_name}-db-credentials"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = aws_db_instance.db.address
    port     = aws_db_instance.db.port
    username = aws_db_instance.db.username
    password = random_password.db.result
    dbname   = aws_db_instance.db.db_name
  })
}

### Instancia EC2 con la app desplegada vía user_data
resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.todo_key.key_name
  vpc_security_group_ids      = [aws_security_group.todo_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url       = var.repo_url
    app_port       = var.app_port
    db_secret_name = aws_secretsmanager_secret.db.name
    region         = var.region
  })
  user_data_replace_on_change = true

  # La app lee el secreto al arrancar, así que la BD y el secreto deben existir antes
  depends_on = [aws_secretsmanager_secret_version.db]

  tags = {
    Name = "${var.project_name}-server"
  }
}