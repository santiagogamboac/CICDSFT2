# Integración continua – Docker con dos contenedores + Jenkins

[![Docker CI](https://github.com/santiagogamboac/CICDSFT2/actions/workflows/docker-ci.yml/badge.svg)](https://github.com/santiagogamboac/CICDSFT2/actions/workflows/docker-ci.yml)

Aplicación de **notas** formada por dos contenedores que se comunican dentro de una red propia de Docker:

| Servicio | Papel | Imagen | Puerto |
|----------|-------|--------|--------|
| `app` (contenedor 1) | Frontend web + API REST en Node.js/Express | `notas-app:1.0.0` (Dockerfile propio, base `node:20.18-alpine`) | `8080` (host) → `3000` (contenedor) |
| `db` (contenedor 2) | Base de datos PostgreSQL con volumen persistente | `notas-db:1.0.0` (Dockerfile propio, base `postgres:16.4-alpine`) | `5432` solo dentro de la red |

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
├── db/                      # Contenedor 2: base de datos
│   ├── Dockerfile
│   └── init.sql             # crea la tabla "notas"
├── jenkins/                 # Entrega 2: Jenkins en contenedor
│   ├── Dockerfile           # jenkins/jenkins LTS + cliente Docker
│   └── docker-compose.yml   # volumen jenkins_home, puertos 8080 y 50000
├── tests/
│   └── test_comunicacion.sh # prueba de integración app <-> db
├── docs/
│   ├── Evidencias_Proyecto1_Docker.pdf
│   └── Entrega2_Jenkins.pdf
├── Jenkinsfile              # Entrega 2: pipeline como código
├── .github/workflows/docker-ci.yml   # Pipeline de GitHub Actions (Entrega 1)
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

Abrir **http://localhost:8080** en el navegador (si Jenkins ya usa el 8080, poner `APP_PUBLIC_PORT=8081` en `.env`): se puede escribir una nota, guardarla y verla en la lista (se lee de PostgreSQL).

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

## Entrega 2 – Jenkins como gestor de operaciones

Jenkins corre en un contenedor (`jenkins/jenkins` LTS) con el volumen `jenkins_home` y usa el Docker
del host para construir y probar los dos contenedores de la Entrega 1. El pipeline está definido como
código en el [`Jenkinsfile`](Jenkinsfile).

```
commit/push ─▶ GitHub (main) ─▶ Jenkins (Poll SCM) ─▶ Checkout ─▶ Build ─▶ Test ─▶ post
                                                        │           │         │        └ logs + docker compose down
                                                        │           │         └ compose up + tests/test_comunicacion.sh
                                                        │           └ imágenes notas-app y notas-db
                                                        └ git clone del repositorio
```

### 1. Levantar Jenkins

```bash
docker compose -f jenkins/docker-compose.yml up -d --build
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword   # contraseña inicial
```

Abrir **http://localhost:8080**, pegar la contraseña inicial, elegir **Install suggested plugins**
(incluye Git, GitHub y Pipeline) y crear el usuario administrador.

### 2. Plugins adicionales

*Administrar Jenkins → Plugins → Available plugins*: instalar **Docker Pipeline** y **Pipeline: Stage View**.

### 3. Credencial de la base de datos (no se escribe en el código)

*Administrar Jenkins → Credentials → System → Global → Add Credentials*:

| Campo | Valor |
|-------|-------|
| Kind | Username with password |
| Username | `notas_user` |
| Password | la contraseña que se quiera usar para PostgreSQL |
| ID | `notas-db-credentials` |

El pipeline lee esta credencial con `credentials('notas-db-credentials')`, genera el `.env` en el
workspace y lo borra al terminar. Jenkins enmascara la contraseña en la consola.

### 4. Crear el job

*Nueva Tarea → `notas-docker-pipeline` → Pipeline*:

- **Triggers:** marcar *Consultar repositorio (SCM)* con el horario `H/2 * * * *`.
- **Pipeline → Definition:** *Pipeline script from SCM* → **Git**
  - Repository URL: `https://github.com/santiagogamboac/CICDSFT2.git`
  - Branch: `*/main`
  - Script Path: `Jenkinsfile`

A partir de ahí cada `git push` a `main` dispara el pipeline solo (Jenkins revisa GitHub cada 2 minutos).

### Etapas del pipeline

| Etapa | Qué hace |
|-------|----------|
| **Checkout** | Descarga el commit desde GitHub. |
| **Build** | Genera el `.env` con la credencial de Jenkins, valida el compose y construye las imágenes `notas-app` y `notas-db` con el plugin Docker Pipeline. |
| **Test** | `docker compose up -d --wait` y ejecuta `tests/test_comunicacion.sh`: verifica que `DB_HOST=db`, que el DNS de Docker resuelve `db`, y que una nota se guarda y se lee de PostgreSQL. Si algo falla, el build queda en rojo. |
| **post** | Siempre: guarda `compose-logs.txt` como artefacto, apaga los contenedores y borra el `.env`. |

Las evidencias (capturas de la instalación, vista de etapas, consola, un build que falla y el que lo
corrige) están en [`docs/Entrega2_Jenkins.pdf`](docs/Entrega2_Jenkins.pdf).

## GitHub Actions (Entrega 1)

El workflow `.github/workflows/docker-ci.yml` se mantiene: en cada `push` y `pull_request` construye las
imágenes, levanta los contenedores y ejecuta la misma prueba `tests/test_comunicacion.sh`.
