# 3. Database Choice and Justification

The project uses two database paradigms, each for the kind of data it handles best.

## MySQL 8 (relational): system of record

Used for: customers, products, units, sales, warranties, recalls, service requests, repairs, parts, claims, users.

Why relational:

1. The data is highly structured and connected. A claim depends on a warranty, which depends on a unit, which depends on a sale and a customer. Foreign keys guarantee that none of these links can break.
2. Business rules must hold no matter who writes the data. CHECK constraints, UNIQUE keys and triggers refuse invalid data even if the application has a bug.
3. Several operations change many tables at once (a replacement touches six). ACID transactions make these all-or-nothing.
4. Reports need joins, grouping and aggregation (revenue by brand, technician workload, claim outcomes), which SQL does directly.

MySQL rather than PostgreSQL for this part because the team already used MySQL in the course labs, and it supports every feature needed: CHECK constraints, triggers, stored procedures, window functions, CTEs, full-text indexes and events.

## PostgreSQL 16 + pgvector (vector): semantic search

Used for: one embedding per service request.

Why a vector database:

1. Complaint descriptions are free text, and the same problem is described in many ways. "Phone dies at 20 percent" and "battery drains fast" share almost no words.
2. MySQL full-text search matches words, not meaning. In testing, searching "telly will not switch on" with full-text ranked a water-damaged phone first, only because both texts contain the word "not". The vector search ranked the correct request ("TV does not power on") first.
3. pgvector stores 384-dimension vectors, computes cosine distance and indexes it with HNSW for fast nearest neighbour search, all inside a normal SQL database that also supports metadata filters.

## Why not one database for everything

| Option | Problem |
|---|---|
| Only MySQL | No vector type or vector index; similarity would have to be computed in application code over every row. |
| Only a NoSQL store | Loses foreign keys, CHECK constraints and multi-table transactions, which the warranty and claim rules depend on. |
| MySQL + pgvector (chosen) | Each database does what it is designed for. The only cost is keeping request_id in step, which the application handles (see section 7). |
