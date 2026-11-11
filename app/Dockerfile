# Contenedor 1: aplicación web (Node.js + Express)
# Imagen base oficial con versión fija (no "latest")
FROM node:20.18-alpine

WORKDIR /usr/src/app

# Instalar dependencias primero para aprovechar la caché de capas
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copiar el código de la aplicación
COPY server.js ./
COPY public ./public

# Ejecutar como usuario sin privilegios (incluido en la imagen oficial)
USER node

ENV APP_PORT=3000
EXPOSE 3000

CMD ["node", "server.js"]
