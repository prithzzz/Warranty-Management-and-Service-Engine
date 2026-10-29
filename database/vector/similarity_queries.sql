-- In the application the query vector comes from the embedding model; here an existing request's vector is reused so the queries run in psql.
-- Run:  psql -d warranty_vectors -f vector/similarity_queries.sql

-- Q1: five past requests most similar to request 14, any product
SELECT e.request_id, e.model_name, e.issue_type,
       ROUND((1 - (e.embedding <=> q.embedding))::numeric, 3) AS cosine_similarity,
       LEFT(e.issue_text, 60) AS issue
FROM issue_embedding e,
     (SELECT embedding FROM issue_embedding WHERE request_id = 14) AS q
WHERE e.request_id <> 14
ORDER BY e.embedding <=> q.embedding
LIMIT 5;

-- Q2: same search restricted to the same product category (metadata filter)
SELECT e.request_id, e.model_name,
       ROUND((1 - (e.embedding <=> q.embedding))::numeric, 3) AS cosine_similarity,
       LEFT(e.resolution_text, 60) AS how_it_was_fixed
FROM issue_embedding e,
     (SELECT embedding, product_category FROM issue_embedding WHERE request_id = 14) AS q
WHERE e.request_id <> 14
  AND e.product_category = q.product_category
ORDER BY e.embedding <=> q.embedding
LIMIT 5;

-- Q3: only confident matches (similarity above 0.5) that already have a fix
SELECT e.request_id, e.model_name,
       ROUND((1 - (e.embedding <=> q.embedding))::numeric, 3) AS cosine_similarity
FROM issue_embedding e,
     (SELECT embedding FROM issue_embedding WHERE request_id = 12) AS q
WHERE e.request_id <> 12
  AND e.resolution_text IS NOT NULL
  AND 1 - (e.embedding <=> q.embedding) > 0.5
ORDER BY e.embedding <=> q.embedding;

-- Q4: how many requests are embedded per category (aggregation on the vector store)
SELECT product_category, COUNT(*) AS embedded_requests,
       SUM(CASE WHEN resolution_text IS NULL THEN 0 ELSE 1 END) AS with_resolution
FROM issue_embedding
GROUP BY product_category
ORDER BY embedded_requests DESC;

-- Q5: the index is used for nearest neighbour search
EXPLAIN
SELECT request_id FROM issue_embedding
ORDER BY embedding <=> (SELECT embedding FROM issue_embedding WHERE request_id = 1)
LIMIT 5;
