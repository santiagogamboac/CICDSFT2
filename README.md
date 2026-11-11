# Proyecto 1 – Docker con dos contenedores comunicados

[![Docker CI](https://github.com/santiagogamboac/CICDSFT2/actions/workflows/docker-ci.yml/badge.svg)](https://github.com/santiagogamboac/CICDSFT2/actions/workflows/docker-ci.yml)

Aplicación de **notas** formada por dos contenedores que se comunican dentro de una red propia de Docker:

| Servicio | Papel | Imagen | Puerto |
|----------|-------|--------|--------|
| `app` (contenedor 1) | Frontend web + API REST en Node.js/Express | `notas-app:1.0.0` (Dockerfile propio, base `node:20.18-alpine`) | `8080` (host) → `3000` (contenedor) |
| `db` (contenedor 2) | Base de datos PostgreSQL con volumen persistente | `postgres:16.4-alpine` (oficial) | `5432` solo dentro de la red |

La app se conecta a la base de datos usando el **nombre del servicio `db`** (variable `DB_HOST=db`), nunca `localhost` ni una IP fija. El DNS interno de Docker resuelve `db` a la IP del contenedor dentro de la red `red_notas`.

```
 Navegador / curl
       │  http://localhost:8080
       ▼
┌───────────────── red_notas (bridge) ─────────────────┐
│  ┌──────────────┐   DB_HOST=db:5432   ┌────────────┐ │
│  │  app         │ ──────────────────▶ │  db        │ │
│  │  Node 20     │ ◀────────────────── │ Postgres16 │ │
│  └──────────────┘    filas (SQL)      └─────┬──────┘ │
└─────────────────────────────────────────────┼────────┘
                                               ▼
                                   volumen notas_db_data
```

## Estructura del repositorio

```
.
├── app/                     # Contenedor 1: aplicación
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── package.json / package-lock.json
│   ├── server.js            # API: /api/health, /api/notas (GET, POST, DELETE)
│   └── public/index.html    # Frontend
├── db/
│   └── init.sql             # Contenedor 2: crea la tabla "notas"
├── docs/
│   └── Evidencias_Proyecto1_Docker.pdf
├── .github/workflows/docker-ci.yml   # Pipeline de CI
├── docker-compose.yml
├── .env.example             # Plantilla de variables (el .env real NO se sube)
├── .dockerignore
└── .gitignore
```

## Requisitos

- Docker 24+ con Docker Compose v2 (`docker compose version`)

## Cómo levantar los contenedores

```bash
# 1. Clonar
git clone https://github.com/santiagogamboac/CICDSFT2.git
cd CICDSFT2

# 2. Crear el archivo de variables y cambiar la contraseña
cp .env.example .env

# 3. Construir y levantar los dos servicios
docker compose up -d --build

# 4. Ver los contenedores
docker ps
```

Abrir **http://localhost:8080** en el navegador: se puede escribir una nota, guardarla y verla en la lista (se lee de PostgreSQL).

## Probar la comunicación entre contenedores

```bash
# El contenedor app resuelve el nombre del servicio "db"
docker exec notas-app getent hosts db

# Guardar un dato (app -> db)
curl -X POST -H "Content-Type: application/json" \
     -d '{"texto":"Hola desde el contenedor app"}' http://localhost:8080/api/notas

# Leer el dato (db -> app)
curl http://localhost:8080/api/notas

# Comprobarlo directamente en la base de datos
docker exec notas-db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT * FROM notas;"'

# Estado de la conexión
curl http://localhost:8080/api/health
```

## Otros comandos útiles

```bash
docker build -t notas-app:1.0.0 ./app      # construir solo la imagen de la app
docker network inspect red_notas           # ver la red y los contenedores conectados
docker compose logs -f app                 # ver logs
docker compose down                        # apagar (conserva los datos)
docker compose down -v                     # apagar y borrar el volumen de datos
```

## Buenas prácticas aplicadas

- Imágenes base oficiales con versión fija (`node:20.18-alpine`, `postgres:16.4-alpine`), nunca `latest`.
- `.dockerignore` en la raíz y en `app/` para no copiar `node_modules`, `.env` ni `.git` a la imagen.
- Contraseñas solo en `.env` (ignorado por git); en el repositorio solo está `.env.example`.
- La app corre con el usuario sin privilegios `node`.
- La base de datos no publica puertos al host: solo es accesible desde la red `red_notas`.
- `healthcheck` en ambos servicios y `depends_on: condition: service_healthy`.

## Integración continua

El workflow `.github/workflows/docker-ci.yml` se ejecuta en cada `push` y `pull_request`:
valida el `docker-compose.yml`, construye las imágenes, levanta los contenedores y hace una prueba
real de guardar y leer una nota. Si algo falla, el check queda en rojo.
