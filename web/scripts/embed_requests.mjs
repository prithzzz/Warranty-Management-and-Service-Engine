// Embeds every service request from MySQL and stores the vectors in PostgreSQL.
// Run from the web folder:  npm run embed
// Safe to run again: existing rows are updated, not duplicated.
import './loadEnv.mjs';
import mysql from 'mysql2/promise';
import pg from 'pg';
import { embed, toPgVector, requestToText, REQUEST_TEXT_SQL, UPSERT_EMBEDDING_SQL, EMBEDDING_MODEL } from '../lib/embeddings.mjs';

const my = await mysql.createConnection({
  host: process.env.MYSQL_HOST, port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database: process.env.MYSQL_DATABASE
});
const pgClient = new pg.Client({
  host: process.env.PG_HOST, port: Number(process.env.PG_PORT || 5432),
  user: process.env.PG_USER, password: process.env.PG_PASSWORD, database: process.env.PG_DATABASE
});
await pgClient.connect();

console.log(`Loading model ${EMBEDDING_MODEL} (first run downloads about 25 MB)...`);
const [requests] = await my.query(REQUEST_TEXT_SQL + ' ORDER BY sr.request_id');

let done = 0;
for (const r of requests) {
  const vector = await embed(requestToText(r));
  await pgClient.query(UPSERT_EMBEDDING_SQL, [
    r.request_id, r.product_category, r.model_name, r.issue_type,
    r.issue_text, r.resolution_text, toPgVector(vector)
  ]);
  done += 1;
  console.log(`  embedded request ${r.request_id} (${r.model_name}, ${r.issue_type})`);
}

const { rows } = await pgClient.query('SELECT COUNT(*)::int AS n FROM issue_embedding');
console.log(`Done: ${done} requests embedded, ${rows[0].n} vectors stored in PostgreSQL.`);

await my.end();
await pgClient.end();
