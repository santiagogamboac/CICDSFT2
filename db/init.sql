-- Contenedor 2: PostgreSQL
-- Se ejecuta automáticamente la primera vez que se crea el volumen de datos.
CREATE TABLE IF NOT EXISTS notas (
  id     SERIAL PRIMARY KEY,
  texto  VARCHAR(500) NOT NULL,
  creado TIMESTAMP NOT NULL DEFAULT NOW()
);

INSERT INTO notas (texto) VALUES ('Nota inicial creada por init.sql');
