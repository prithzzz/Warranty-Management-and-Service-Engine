# 6. Vector Database: Embeddings and Storage

## What data is converted into embeddings

Each service request becomes one vector. The text that is embedded combines the product model, the issue type, the customer's description and, once the repair is finished, the technician's resolution notes:

```
iPhone 15. battery issue: Battery health dropped quickly and the phone shuts down
at 20 percent Fix: Replaced battery and recalibrated
```

Including the model and the fix means a match tells the technician both that the problem is similar and how it was solved last time.

## Embedding model

| Item | Choice |
|---|---|
| Model | all-MiniLM-L6-v2 (Xenova ONNX build) |
| Library | @xenova/transformers 2.17.2, runs inside Node.js |
| Dimensions | 384 |
| Pooling | mean pooling over tokens, then L2 normalisation |
| Cost | free, runs locally, no API key; about 25 MB downloaded once |

The same model and settings are used when storing vectors and when searching, which is required for the distances to be meaningful. The code is in `web/lib/embeddings.mjs`.

## How vectors are stored

PostgreSQL 16 with the pgvector extension, database `warranty_vectors`, created by `database/vector/vector_setup.sql`.

| Column | Type | Purpose |
|---|---|---|
| request_id | INTEGER PK | same id as service_request in MySQL |
| product_category | VARCHAR(20) | metadata filter (SMARTPHONE, LAPTOP, ...) |
| model_name | VARCHAR(100) | shown in results |
| issue_type | VARCHAR(20) | shown in results |
| issue_text | TEXT | the customer's description |
| resolution_text | TEXT | technician notes, filled after the repair |
| embedding | VECTOR(384) | the normalised embedding |
| embedded_at | TIMESTAMP | when the vector was last written |

Indexes:

- `idx_issue_embedding_hnsw`: HNSW index with `vector_cosine_ops`, for fast approximate nearest neighbour search on cosine distance.
- `idx_issue_embedding_category`: B-tree index on product_category for the metadata filter.
- The primary key on request_id makes re-embedding an update instead of a duplicate (`INSERT ... ON CONFLICT DO UPDATE`).

## How the store is filled

1. Bulk load: `npm run embed` (`web/scripts/embed_requests.mjs`) reads every service request from MySQL, embeds it and upserts it. It is safe to run any number of times.
2. Live sync: the application re-embeds a request when a customer raises it and again when its repair is completed, so the fix becomes searchable immediately (`syncRequestEmbedding` in `web/lib/similarity.js`).

A failed embedding never blocks the MySQL operation; it is logged and the bulk script can repair it later.

## Results

After the bulk load with the sample data, 18 requests were embedded across 4 product categories (9 smartphone, 3 laptop, 3 television, 3 appliance).
