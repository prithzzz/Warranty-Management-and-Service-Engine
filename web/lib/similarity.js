// Semantic search over past service requests (PostgreSQL + pgvector),
// with results joined back to MySQL for the repair details.
import { query } from './mysql';
import { pgQuery } from './postgres';
import { embed, toPgVector, requestToText, REQUEST_TEXT_SQL, UPSERT_EMBEDDING_SQL } from './embeddings.mjs';

// Create or refresh the embedding of one request. Called after a request is
// raised and after its repair is completed (so the fix is included).
// A failure here never blocks the MySQL operation; it is only logged.
export async function syncRequestEmbedding(requestId) {
  try {
    const rows = await query(REQUEST_TEXT_SQL + ' WHERE sr.request_id = ?', [requestId]);
    const r = rows[0];
    if (!r) return false;
    const vector = await embed(requestToText(r));
    await pgQuery(UPSERT_EMBEDDING_SQL, [
      r.request_id, r.product_category, r.model_name, r.issue_type,
      r.issue_text, r.resolution_text, toPgVector(vector)
    ]);
    return true;
  } catch (err) {
    console.error(`Embedding sync failed for request ${requestId}:`, err.message);
    return false;
  }
}

// Find the most similar past requests.
//   { requestId }        : compare against an existing request (excluded from results)
//   { text, category }   : compare against free text, optionally within one product category
export async function findSimilar({ requestId = null, text = null, category = null, limit = 5 }) {
  let vector;
  if (requestId) {
    let stored = await pgQuery(
      'SELECT embedding::text AS v, product_category FROM issue_embedding WHERE request_id = $1',
      [requestId]
    );
    if (!stored[0]) {
      await syncRequestEmbedding(requestId);
      stored = await pgQuery(
        'SELECT embedding::text AS v, product_category FROM issue_embedding WHERE request_id = $1',
        [requestId]
      );
    }
    if (!stored[0]) throw new Error('This request has no embedding yet');
    vector = stored[0].v;
    category = category || stored[0].product_category;
  } else {
    vector = toPgVector(await embed(text));
  }

  // cosine distance (<=>) uses the HNSW index; similarity = 1 - distance
  const matches = await pgQuery(
    `SELECT request_id, model_name, issue_type, issue_text, resolution_text,
            ROUND((1 - (embedding <=> $1::vector))::numeric, 3)::float AS similarity
     FROM issue_embedding
     WHERE ($2::text IS NULL OR product_category = $2)
       AND ($3::int IS NULL OR request_id <> $3)
     ORDER BY embedding <=> $1::vector
     LIMIT $4`,
    [vector, category, requestId, limit]
  );
  if (matches.length === 0) return [];

  // details from MySQL for the matched requests
  const ids = matches.map((m) => m.request_id);
  const details = await query(
    `SELECT sr.request_id, sr.status, DATE(sr.request_date) AS request_date,
            t.full_name AS technician,
            (SELECT GROUP_CONCAT(CONCAT(sp.part_name, ' x', rp.quantity) SEPARATOR ', ')
               FROM repair_part rp JOIN spare_part sp ON sp.part_id = rp.part_id
              WHERE rp.repair_id = r.repair_id) AS parts_used,
            IF(r.repair_id IS NULL, NULL, fn_repair_cost(r.repair_id)) AS repair_cost
     FROM service_request sr
     LEFT JOIN repair r ON r.request_id = sr.request_id AND r.status = 'COMPLETED'
     LEFT JOIN technician t ON t.technician_id = r.technician_id
     WHERE sr.request_id IN (?)`,
    [ids]
  );
  const byId = Object.fromEntries(details.map((d) => [d.request_id, d]));
  return matches.map((m) => ({ ...m, ...(byId[m.request_id] || {}) }));
}
