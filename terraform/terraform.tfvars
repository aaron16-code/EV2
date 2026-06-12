# =====================================================================
# VALORES DE VARIABLES - EP2 Innovatech Chile
# Modifica estos valores segun tu configuracion
# =====================================================================

region              = "us-east-1"
ami_id              = "ami-00e801948462f718a"   # Amazon Linux 2023 (us-east-1)
instance_type       = "t3.micro"
key_pair_name       = "clave-ep2-innovatech"

vpc_cidr            = "10.0.0.0/16"
subnet_publica_cidr = "10.0.1.0/24"
subnet_privada_cidr = "10.0.2.0/24"
availability_zone   = "us-east-1a"

puerto_backend      = 8080   # Spring Boot
puerto_frontend     = 80     # Nginx
