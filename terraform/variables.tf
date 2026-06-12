variable "region" {
  description = "Region de AWS donde se desplegara la infraestructura"
  type        = string
}

variable "ami_id" {
  description = "AMI a usar en las instancias EC2 (Amazon Linux 2023)"
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "key_pair_name" {
  description = "Nombre del Key Pair SSH que se creara en AWS"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC principal"
  type        = string
}

variable "subnet_publica_cidr" {
  description = "CIDR de la subred publica (Frontend)"
  type        = string
}

variable "subnet_privada_cidr" {
  description = "CIDR de la subred privada (Backend)"
  type        = string
}

variable "availability_zone" {
  description = "Zona de disponibilidad para las subredes"
  type        = string
}

variable "puerto_backend" {
  description = "Puerto expuesto por el contenedor Backend (ej: Spring Boot = 8080)"
  type        = number
}

variable "puerto_frontend" {
  description = "Puerto expuesto por el contenedor Frontend (ej: Nginx = 80)"
  type        = number
}
