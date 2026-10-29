// PostgreSQL (pgvector) connection pool. Credentials come from .env.local.
import pg from 'pg';

const globalForPg = globalThis;

export const pgPool =
  globalForPg.pgPool ||
  new pg.Pool({
    host: process.env.PG_HOST,
    port: Number(process.env.PG_PORT || 5432),
    user: process.env.PG_USER,
    password: process.env.PG_PASSWORD,
    database: process.env.PG_DATABASE,
    max: 5
  });

if (process.env.NODE_ENV !== 'production') globalForPg.pgPool = pgPool;

export async function pgQuery(sql, params = []) {
  const result = await pgPool.query(sql, params);
  return result.rows;
}
