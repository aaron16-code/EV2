# ============================================================
# STAGE 1: Build
# Compila la aplicación React + Vite generando los archivos
# estáticos optimizados en la carpeta /app/dist
# ============================================================
FROM node:20-alpine AS builder

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiamos primero solo los archivos de dependencias
# Esto aprovecha el cache de Docker: si package.json no cambia,
# no se reinstalan las dependencias en cada build
COPY package*.json ./

# Instalamos dependencias
RUN npm ci

# Copiamos el resto del código fuente
COPY . .

# Construimos la aplicación para producción
RUN npm run build

# ============================================================
# STAGE 2: Producción
# Imagen final liviana con Nginx para servir los archivos
# estáticos generados en el stage anterior
# ============================================================
FROM nginx:alpine AS production

# Copiamos los archivos compilados desde el stage builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Copiamos configuración personalizada de Nginx
# Necesaria para que React Router funcione correctamente
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Exponemos el puerto 80 (HTTP)
EXPOSE 80

# Ejecutamos Nginx en primer plano (requerido por Docker)
CMD ["nginx", "-g", "daemon off;"]
