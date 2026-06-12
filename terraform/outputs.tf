# =====================================================================
# OUTPUTS - Informacion util tras ejecutar terraform apply
# =====================================================================

output "ip_publica_frontend" {
  description = "IP publica del Frontend (accesible desde el navegador)"
  value       = aws_eip.eip_frontend.public_ip
}

output "ip_privada_backend" {
  description = "IP privada del Backend (solo accesible dentro de la VPC)"
  value       = aws_instance.ec2_backend.private_ip
}

output "url_frontend" {
  description = "URL para acceder al Frontend desde el navegador"
  value       = "http://${aws_eip.eip_frontend.public_ip}"
}

output "ssh_frontend" {
  description = "Comando para conectarse al EC2 Frontend via SSH"
  value       = "ssh -i clave-ep2.pem ec2-user@${aws_eip.eip_frontend.public_ip}"
}

output "ssh_backend_via_frontend" {
  description = "Comando para conectarse al EC2 Backend usando Frontend como Jump Host"
  value       = "ssh -i clave-ep2.pem -J ec2-user@${aws_eip.eip_frontend.public_ip} ec2-user@${aws_instance.ec2_backend.private_ip}"
}

output "vpc_id" {
  description = "ID de la VPC creada"
  value       = aws_vpc.vpc_innovatech.id
}
