# Warranty Management and Service Engine

DBMS Level 3 Project. A web application that tracks every serial-numbered product unit from sale to service: who owns it, which warranty covers it, whether it is in a recall batch, and every repair, claim and replacement. Business rules live in the database, and past repairs can be searched by meaning with vector embeddings.

## Tech stack

| Part | Technology |
|---|---|
| Frontend and backend | Next.js 14 (App Router, API route handlers), React 18 |
| Relational database | MySQL 8.0.16 or later |
| Vector database | PostgreSQL 16 with pgvector |
| Embeddings | all-MiniLM-L6-v2 through @xenova/transformers (free, runs locally) |
| Auth | bcrypt password hashes, signed JWT in an httpOnly cookie, 4 roles |

## Repository structure

```
database/
  build_all.sql              builds the MySQL database (both modules + tests)
  common/                    database creation and test framework
  sales_module/              Sales, Warranty and Recall (tables, logic, data, queries, tests)
  service_module/            Service, Repair and Claims (tables, logic, data, queries, tests)
  vector/
    vector_setup.sql         pgvector table and indexes
    similarity_queries.sql   example vector searches
web/
  app/                       pages and API routes
  components/                shared UI components
  lib/                       database connections, auth, embeddings, similarity search
  scripts/                   embed_requests.mjs (bulk embedding), test_similarity.mjs
  middleware.js              session and role checks
  .env.example               configuration template
docs/                        project report sections
```

## Setup (macOS)

### 1. Install the tools (once)

- MySQL 8: already installed if `mysql --version` works.
- PostgreSQL with pgvector: install Postgres.app from postgresapp.com (pgvector is included). Open it and click Initialize. Then add its tools to Terminal:
  `echo 'export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc`
- Node.js 20 LTS from nodejs.org (or `brew install node@20`). Check with `node -v`.

### 2. Build the MySQL database

```bash
cd database
mysql -u root -p -t < build_all.sql
```

The last table should show SALES 20/20 and SERVICE 25/25.

### 3. Create the vector database

```bash
createdb warranty_vectors
psql -d warranty_vectors -f vector/vector_setup.sql
```

### 4. Configure the web app

```bash
cd ../web
cp .env.example .env.local
```

Open `.env.local` and fill in your MySQL password. With Postgres.app, set `PG_USER` to your Mac username (run `whoami`) and leave `PG_PASSWORD` empty. Set `JWT_SECRET` to any long random text.

### 5. Install packages and embed the service requests

```bash
npm install
npm run embed
npm run test:vector
```

The first `npm run embed` downloads the embedding model (about 25 MB). `test:vector` should end with 8 of 8 passed.

### 6. Start the app

```bash
npm run dev
```

Open http://localhost:3000.

## Demo accounts

All use the password `Password@123`.

| Username | Role | Sees |
|---|---|---|
| admin | ADMIN | everything |
| staff.jayanagar | SERVICE_STAFF | Jayanagar center queue, sales, recalls, claims |
| staff.whitefield | SERVICE_STAFF | Whitefield center |
| tech.arjun | TECHNICIAN | his repair jobs |
| ananya, rahul, priya, karthik, nikhil | CUSTOMER | their own products and requests |

## Rebuilding

Running `build_all.sql` again resets all MySQL data. After that, run `npm run embed` again so PostgreSQL matches.

## Requirement coverage

| Requirement | Where |
|---|---|
| ER diagram, relational schema | docs/02_er_and_relational_schema.md |
| SQL DDL: CREATE, ALTER, DROP, keys, constraints, indexes, views | database/*_module/tables.sql, procedures_triggers.sql |
| DML and queries: JOIN, GROUP BY, HAVING, subqueries, CTE, windows | database/*_module/sample_data.sql, queries.sql |
| Advanced SQL: transactions, procedures, functions, triggers, views, indexing, full-text search, event | database/*_module/procedures_triggers.sql |
| Vector: embeddings, storage, similarity metric, retrieval | database/vector, web/lib/embeddings.mjs, web/lib/similarity.js, docs 06 and 07 |
| Next.js interface with forms, tables, search, dashboards | web/app |
| API layer and environment variables | web/app/api, web/lib, web/.env.example |
| Authentication, minimum two roles | web/middleware.js, web/lib/auth.js, app_user table |
| Validation and integrity at database level | CHECK, UNIQUE, FK, triggers; tests in database/*/tests.sql |
| Documentation and test results | docs/ |
