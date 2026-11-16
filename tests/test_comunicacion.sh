#!/bin/sh
# Prueba de integración: verifica que el contenedor "app" se comunica con el
# contenedor "db" usando el NOMBRE DEL SERVICIO dentro de la red de Docker.
# Requiere que los servicios ya estén arriba (docker compose up -d --wait).
# Si cualquier verificación falla, el script termina con código distinto de 0.
set -eu

NOTA="nota-de-prueba-$(date +%s)-$$"
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLO] $1"; exit 1; }

echo "1) La app está configurada con el nombre del servicio (no localhost ni IP)"
DB_HOST_APP=$(docker compose exec -T app printenv DB_HOST)
[ "$DB_HOST_APP" = "db" ] || fail "DB_HOST debería ser 'db' y es '$DB_HOST_APP'"
ok "DB_HOST=$DB_HOST_APP"

echo "2) El DNS interno de Docker resuelve 'db' desde el contenedor app"
IP_DB=$(docker compose exec -T app getent hosts db | awk '{print $1}')
[ -n "$IP_DB" ] || fail "el nombre 'db' no se resuelve desde app"
ok "db -> $IP_DB"

echo "3) GUARDAR: la app inserta una nota en PostgreSQL"
RESP=$(docker compose exec -T app wget -qO- \
  --header 'Content-Type: application/json' \
  --post-data "{\"texto\":\"$NOTA\"}" http://localhost:3000/api/notas)
echo "$RESP" | grep -q "$NOTA" || fail "la app no confirmó la nota guardada: $RESP"
ok "$RESP"

echo "4) LEER: la app devuelve la nota leída desde PostgreSQL"
docker compose exec -T app wget -qO- http://localhost:3000/api/notas | grep -q "$NOTA" \
  || fail "la nota no aparece en GET /api/notas"
ok "la nota aparece en GET /api/notas"

echo "5) La nota existe físicamente en el contenedor db"
FILAS=$(docker compose exec -T db sh -c \
  "psql -U \"\$POSTGRES_USER\" -d \"\$POSTGRES_DB\" -tAc \"SELECT count(*) FROM notas WHERE texto = '$NOTA'\"")
[ "$FILAS" = "1" ] || fail "se esperaba 1 fila en la tabla notas y hay '$FILAS'"
ok "1 fila en la tabla notas"

echo "6) Estado de la conexión reportado por la app"
SALUD=$(docker compose exec -T app wget -qO- http://localhost:3000/api/health)
echo "$SALUD" | grep -q '"db":"ok"' || fail "la app no reporta la base de datos en ok: $SALUD"
echo "$SALUD" | grep -q '"db_host":"db"' || fail "la app no usa el host 'db': $SALUD"
ok "$SALUD"

echo "RESULTADO: los dos contenedores se comunican por el nombre del servicio."
