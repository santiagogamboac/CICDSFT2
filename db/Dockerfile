# Contenedor 2: base de datos PostgreSQL
# Imagen base oficial con versión fija (no "latest")
FROM postgres:16.4-alpine

# Script que crea la tabla "notas" la primera vez que se inicializa el volumen
COPY init.sql /docker-entrypoint-initdb.d/init.sql

EXPOSE 5432
