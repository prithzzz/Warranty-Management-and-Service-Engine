-- =====================================================================
-- vector/vector_setup.sql
-- PostgreSQL + pgvector store for semantic search over service requests.
-- Run once:  psql -d warranty_vectors -f vector/vector_setup.sql
--
-- MySQL (warranty_engine) stays the system of record. This database holds
-- only an embedding per service request, keyed by the same request_id, so
-- search results can be joined back to MySQL by the application.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS vector;

DROP TABLE IF EXISTS issue_embedding;

CREATE TABLE issue_embedding (
  request_id        INTEGER      PRIMARY KEY,          -- = service_request.request_id in MySQL
  product_category  VARCHAR(20)  NOT NULL,             -- SMARTPHONE, LAPTOP, TELEVISION, ...
  model_name        VARCHAR(100) NOT NULL,
  issue_type        VARCHAR(20)  NOT NULL,
  issue_text        TEXT         NOT NULL,             -- customer description
  resolution_text   TEXT,                              -- technician notes once repaired
  embedding         VECTOR(384)  NOT NULL,             -- all-MiniLM-L6-v2 output, L2-normalised
  embedded_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_category CHECK (product_category IN
    ('SMARTPHONE','LAPTOP','TABLET','TELEVISION','APPLIANCE','WEARABLE','AUDIO')),
  CONSTRAINT chk_issue_text CHECK (char_length(issue_text) >= 10)
);

-- Approximate nearest neighbour index for cosine distance (the <=> operator)
CREATE INDEX idx_issue_embedding_hnsw
  ON issue_embedding USING hnsw (embedding vector_cosine_ops);

-- Metadata filter used together with the vector search
CREATE INDEX idx_issue_embedding_category ON issue_embedding (product_category);
