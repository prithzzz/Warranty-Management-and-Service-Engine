// Text embeddings with the free all-MiniLM-L6-v2 model (runs locally, no API key).
// The model (about 25 MB) is downloaded once on first use and then cached.
// This is an .mjs file so both Next.js and the Node scripts in /scripts can import it.
import { pipeline } from '@xenova/transformers';

export const EMBEDDING_MODEL = 'Xenova/all-MiniLM-L6-v2';
export const EMBEDDING_DIMENSIONS = 384;

let extractorPromise = null;

function getExtractor() {
  if (!extractorPromise) extractorPromise = pipeline('feature-extraction', EMBEDDING_MODEL);
  return extractorPromise;
}

// Returns 384 numbers. Mean pooling + L2 normalisation, so cosine
// similarity between two vectors is simply their dot product.
export async function embed(text) {
  const extractor = await getExtractor();
  const output = await extractor(text, { pooling: 'mean', normalize: true });
  return Array.from(output.data);
}

// pgvector reads vectors written as '[0.1,0.2,...]'
export function toPgVector(values) {
  return '[' + values.join(',') + ']';
}

// The text stored for one service request: product, issue and, once
// repaired, how it was fixed.
export function requestToText({ model_name, issue_type, issue_text, resolution_text }) {
  let text = `${model_name}. ${issue_type.replace(/_/g, ' ').toLowerCase()} issue: ${issue_text}`;
  if (resolution_text) text += ` Fix: ${resolution_text}`;
  return text;
}

// MySQL query that collects everything needed to embed service requests.
// Add "WHERE sr.request_id = ?" to fetch a single request.
export const REQUEST_TEXT_SQL = `
  SELECT sr.request_id, p.category AS product_category, pm.model_name, sr.issue_type,
         sr.issue_description AS issue_text,
         (SELECT GROUP_CONCAT(r.resolution_notes SEPARATOR ' ')
            FROM repair r
           WHERE r.request_id = sr.request_id AND r.status = 'COMPLETED') AS resolution_text
  FROM service_request sr
  JOIN serial_unit s    ON s.serial_id = sr.serial_id
  JOIN product_model pm ON pm.model_id = s.model_id
  JOIN product p        ON p.product_id = pm.product_id`;

// PostgreSQL insert-or-update for one request
export const UPSERT_EMBEDDING_SQL = `
  INSERT INTO issue_embedding
    (request_id, product_category, model_name, issue_type, issue_text, resolution_text, embedding)
  VALUES ($1, $2, $3, $4, $5, $6, $7::vector)
  ON CONFLICT (request_id) DO UPDATE SET
    product_category = EXCLUDED.product_category,
    model_name       = EXCLUDED.model_name,
    issue_type       = EXCLUDED.issue_type,
    issue_text       = EXCLUDED.issue_text,
    resolution_text  = EXCLUDED.resolution_text,
    embedding        = EXCLUDED.embedding,
    embedded_at      = NOW()`;
