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
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# =====================================================================
# 1. GENERACIÓN AUTOMÁTICA DE CLAVES SSH (.PEM)
# =====================================================================

resource "tls_private_key" "clave_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.clave_ssh.public_key_openssh
}

resource "local_file" "guardar_clave" {
  content         = tls_private_key.clave_ssh.private_key_pem
  filename        = "${path.module}/clave-ep2.pem"
  file_permission = "0400"
}

# =====================================================================
# 2. RED: VPC, SUBREDES Y GATEWAYS
# =====================================================================

resource "aws_vpc" "vpc_innovatech" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "vpc-innovatech-ep2" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc_innovatech.id
  tags   = { Name = "igw-innovatech" }
}

# EIP dedicada al NAT Gateway
resource "aws_eip" "eip_nat" {
  domain = "vpc"
  tags   = { Name = "eip-nat-innovatech" }
}

# NAT Gateway en subred pública → da salida a internet al Backend (para pulls de Docker)
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip_nat.id
  subnet_id     = aws_subnet.subred_publica.id
  tags          = { Name = "nat-gw-innovatech" }
  depends_on    = [aws_internet_gateway.igw]
}

# Subred pública → Frontend (accesible desde Internet)
resource "aws_subnet" "subred_publica" {
  vpc_id                  = aws_vpc.vpc_innovatech.id
  cidr_block              = var.subnet_publica_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags = { Name = "subred-publica-frontend" }
}

# Subred privada → Backend + BD (NO accesible desde Internet)
resource "aws_subnet" "subred_privada" {
  vpc_id            = aws_vpc.vpc_innovatech.id
  cidr_block        = var.subnet_privada_cidr
  availability_zone = var.availability_zone
  tags = { Name = "subred-privada-backend" }
}

# =====================================================================
# 3. TABLAS DE RUTEO
# =====================================================================

# Tabla pública → sale por Internet Gateway
resource "aws_route_table" "rt_publica" {
  vpc_id = aws_vpc.vpc_innovatech.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-publica" }
}

resource "aws_route_table_association" "frontend_assoc" {
  subnet_id      = aws_subnet.subred_publica.id
  route_table_id = aws_route_table.rt_publica.id
}

# Tabla privada → sale por NAT Gateway (para que el Backend pueda hacer docker pull)
resource "aws_route_table" "rt_privada" {
  vpc_id = aws_vpc.vpc_innovatech.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = { Name = "rt-privada" }
}

resource "aws_route_table_association" "backend_assoc" {
  subnet_id      = aws_subnet.subred_privada.id
  route_table_id = aws_route_table.rt_privada.id
}

# =====================================================================
# 4. SECURITY GROUPS
# =====================================================================

# SG Frontend: HTTP/HTTPS público + SSH para CI/CD
resource "aws_security_group" "sg_frontend" {
  name        = "sg-frontend-ep2"
  description = "Trafico web publico hacia el contenedor Frontend"
  vpc_id      = aws_vpc.vpc_innovatech.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP publico"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS publico"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH para deploy via GitHub Actions"
  }

  ingress {
    from_port   = var.puerto_frontend
    to_port     = var.puerto_frontend
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Puerto del contenedor Frontend"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-frontend" }
}

# SG Backend: solo acepta tráfico DESDE el SG Frontend (subred privada)
resource "aws_security_group" "sg_backend" {
  name        = "sg-backend-ep2"
  description = "Trafico al Backend solo desde el Frontend"
  vpc_id      = aws_vpc.vpc_innovatech.id

  ingress {
    from_port       = var.puerto_backend
    to_port         = var.puerto_backend
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_frontend.id]
    description     = "API Backend desde Frontend"
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_frontend.id]
    description     = "SSH desde Frontend (Jump Host para CI/CD)"
  }

  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sg_frontend.id]
    description     = "ICMP diagnostico"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-backend" }
}

# =====================================================================
# 5. INSTANCIAS EC2
# =====================================================================

# EC2 Frontend — subred pública
resource "aws_instance" "ec2_frontend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subred_publica.id
  vpc_security_group_ids = [aws_security_group.sg_frontend.id]
  key_name               = aws_key_pair.key_pair.key_name
  tags                   = { Name = "ec2-frontend-innovatech" }

  user_data = <<-EOF
              #!/bin/bash
              # Actualizar sistema
              yum update -y && yum upgrade -y

              # Instalar Docker
              yum install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              # Instalar Docker Compose v2
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Instalar Git
              yum install git -y

              # Validar
              docker --version >> /var/log/user-data.log 2>&1
              docker compose version >> /var/log/user-data.log 2>&1
              git --version >> /var/log/user-data.log 2>&1
              echo "EC2 Frontend lista - $(date)" >> /var/log/user-data.log
              EOF
}

# EIP para el Frontend (IP pública fija)
resource "aws_eip" "eip_frontend" {
  instance = aws_instance.ec2_frontend.id
  domain   = "vpc"
  tags     = { Name = "eip-frontend-innovatech" }
}

# EC2 Backend — subred privada
resource "aws_instance" "ec2_backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subred_privada.id
  vpc_security_group_ids = [aws_security_group.sg_backend.id]
  key_name               = aws_key_pair.key_pair.key_name
  tags                   = { Name = "ec2-backend-innovatech" }

  user_data = <<-EOF
              #!/bin/bash
              # Actualizar sistema
              yum update -y && yum upgrade -y

              # Instalar Docker
              yum install docker -y
              systemctl enable docker
              systemctl start docker
              usermod -aG docker ec2-user

              # Instalar Docker Compose v2
              mkdir -p /usr/local/lib/docker/cli-plugins
              curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
                -o /usr/local/lib/docker/cli-plugins/docker-compose
              chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

              # Instalar Git
              yum install git -y

              # Validar
              docker --version >> /var/log/user-data.log 2>&1
              docker compose version >> /var/log/user-data.log 2>&1
              git --version >> /var/log/user-data.log 2>&1
              echo "EC2 Backend lista - $(date)" >> /var/log/user-data.log
              EOF
}
