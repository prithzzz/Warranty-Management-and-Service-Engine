# 7. Vector Database: Similarity Search and Retrieval

## Similarity metric

Cosine distance, the pgvector operator `<=>`. Because all vectors are L2-normalised, cosine similarity is `1 - distance`, a score between -1 and 1 where higher means more similar. The HNSW index is built with `vector_cosine_ops`, so ORDER BY `embedding <=> query` uses the index.

## Retrieval strategy

1. Build the query vector.
   - For an existing request, reuse its stored vector (no model call).
   - For free text typed by staff, embed it with the same model used for storage.
2. Search PostgreSQL for the five nearest vectors, excluding the request itself and filtered to the same product category when known:

```sql
SELECT request_id, model_name, issue_type, issue_text, resolution_text,
       ROUND((1 - (embedding <=> $1::vector))::numeric, 3) AS similarity
FROM issue_embedding
WHERE ($2::text IS NULL OR product_category = $2)
  AND ($3::int IS NULL OR request_id <> $3)
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

3. Join back to MySQL with the matched request ids to fetch live details: status, technician, parts used and repair cost (`fn_repair_cost`).
4. Show the matches on the request page and the service queue page, each with its match percentage and how it was fixed.

The code is in `web/lib/similarity.js`, exposed as `GET /api/similar?request_id=` and `GET /api/similar?text=&category=`.

## Keeping the two databases consistent

MySQL is the source of truth. A request is embedded after it is created and re-embedded when its repair completes, so the vector store gains the resolution. If embedding fails, the MySQL operation still succeeds and the bulk script (`npm run embed`) can be re-run to repair any gaps, because it upserts by request_id.

## Example queries

`database/vector/similarity_queries.sql` contains five queries that run directly in psql: top matches for a request, the same with a category filter, a similarity threshold above 0.5, an aggregation of vectors per category, and an EXPLAIN showing the HNSW index scan:

```
Index Scan using idx_issue_embedding_hnsw on issue_embedding
  Order By: (embedding <=> $0)
```

## Example result

Values from our test run; exact scores can differ slightly between machines.

Searching for request 14 ("Battery health dropped quickly and the phone shuts down at 20 percent"):

| Match | Request | Model | Similarity | How it was fixed |
|---|---|---|---|---|
| 1 | 17 | iPhone 15 | 0.734 | Battery replaced, second visit for this unit |
| 2 | 5 | Inspiron 15 3530 | 0.535 | Battery replaced, calibration done |
| 3 | 1 | iPhone 15 | 0.524 | Replaced display assembly |

The best match is the same kind of fault on the same model, even though the two descriptions share few words.
