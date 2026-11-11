// Contenedor 1: aplicación web (frontend + API REST)
// Se conecta al contenedor 2 (PostgreSQL) usando el NOMBRE DEL SERVICIO "db".
const express = require('express');
const path = require('path');
const { Pool } = require('pg');

const PORT = process.env.APP_PORT || 3000;

// Todos los datos de conexión llegan por variables de entorno (archivo .env).
const pool = new Pool({
  host: process.env.DB_HOST, // "db" -> nombre del servicio en docker-compose
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.POSTGRES_USER,
  password: process.env.POSTGRES_PASSWORD,
  database: process.env.POSTGRES_DB,
});

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Salud: confirma que la app llega a la base de datos
app.get('/api/health', async (_req, res) => {
  try {
    const r = await pool.query('SELECT version() AS version, inet_server_addr() AS ip');
    res.json({
      app: 'ok',
      db: 'ok',
      db_host: process.env.DB_HOST,
      db_ip: r.rows[0].ip,
      version: r.rows[0].version,
    });
  } catch (err) {
    res.status(500).json({ app: 'ok', db: 'error', detalle: err.message });
  }
});

// LEER: lista las notas guardadas en PostgreSQL
app.get('/api/notas', async (_req, res) => {
  try {
    const r = await pool.query('SELECT id, texto, creado FROM notas ORDER BY id DESC');
    res.json(r.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GUARDAR: inserta una nota en PostgreSQL
app.post('/api/notas', async (req, res) => {
  const texto = String((req.body && req.body.texto) || '').trim();
  if (!texto) return res.status(400).json({ error: 'El campo "texto" es obligatorio' });
  try {
    const r = await pool.query(
      'INSERT INTO notas (texto) VALUES ($1) RETURNING id, texto, creado',
      [texto]
    );
    res.status(201).json(r.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// BORRAR una nota
app.delete('/api/notas/:id', async (req, res) => {
  try {
    await pool.query('DELETE FROM notas WHERE id = $1', [req.params.id]);
    res.status(204).end();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`App escuchando en el puerto ${PORT}; base de datos en host "${process.env.DB_HOST}"`);
});
