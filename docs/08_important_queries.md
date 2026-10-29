# 8. Important Queries

All queries are in `database/sales_module/queries.sql`, `database/service_module/queries.sql` and `database/vector/similarity_queries.sql`. The most important ones are listed here.

## 1. Auto-assign the best technician (subquery in ORDER BY)

Same center, matching specialization first, then fewest open jobs, then experts for urgent work.

```sql
SELECT t.technician_id
FROM technician t
WHERE t.center_id = v_center AND t.is_active
ORDER BY (t.specialization = v_category) DESC,
         (SELECT COUNT(*) FROM repair r
           WHERE r.technician_id = t.technician_id
             AND r.status IN ('ASSIGNED','IN_PROGRESS')) ASC,
         CASE WHEN v_priority IN ('HIGH','URGENT')
              THEN FIELD(t.skill_level, 'EXPERT','SENIOR','JUNIOR')
              ELSE FIELD(t.skill_level, 'JUNIOR','SENIOR','EXPERT') END
LIMIT 1;
```

## 2. Pick the warranty that covers a claim

Accidental damage plans cover physical damage only; standard and extended plans cover everything else.

```sql
SELECT w.warranty_id
FROM warranty w
JOIN warranty_plan wp ON wp.plan_id = w.plan_id
WHERE w.serial_id = v_serial
  AND w.status <> 'VOID'
  AND v_date BETWEEN w.start_date AND w.end_date
  AND (v_issue = 'PHYSICAL_DAMAGE') = (wp.plan_type = 'ACCIDENTAL_DAMAGE')
ORDER BY w.end_date DESC
LIMIT 1;
```

## 3. Center workload (GROUP BY, HAVING, aggregates)

```sql
SELECT sc.center_code, COUNT(sr.request_id) AS total_requests,
       SUM(sr.status IN ('OPEN','ASSIGNED','IN_PROGRESS')) AS open_requests,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, sr.request_date, sr.closed_at)), 1) AS avg_hours_to_close
FROM service_center sc
JOIN service_request sr ON sr.center_id = sc.center_id
GROUP BY sc.center_id, sc.center_code
HAVING total_requests >= 3
ORDER BY total_requests DESC;
```

## 4. Claim outcomes by plan type (CASE inside aggregates)

```sql
SELECT wp.plan_type, COUNT(*) AS claims,
       SUM(wc.status = 'SETTLED') AS settled,
       SUM(wc.status = 'REJECTED') AS rejected,
       COALESCE(SUM(wc.approved_amount), 0) AS amount_paid
FROM warranty_claim wc
JOIN warranty w ON w.warranty_id = wc.warranty_id
JOIN warranty_plan wp ON wp.plan_id = w.plan_id
GROUP BY wp.plan_type;
```

## 5. Repeat visits within a year (window function LAG)

```sql
SELECT serial_no, request_id, request_date,
       DATEDIFF(request_date, prev_request_date) AS days_since_last
FROM (
  SELECT s.serial_no, sr.request_id, sr.request_date,
         LAG(sr.request_date) OVER (PARTITION BY sr.serial_id ORDER BY sr.request_date) AS prev_request_date
  FROM service_request sr JOIN serial_unit s ON s.serial_id = sr.serial_id
) v
WHERE prev_request_date IS NOT NULL AND DATEDIFF(request_date, prev_request_date) <= 365;
```

## 6. Sold units with no live warranty (correlated NOT EXISTS)

```sql
SELECT c.full_name, s.serial_no
FROM serial_unit s
JOIN customer c ON c.customer_id = s.current_owner_id
WHERE s.status = 'SOLD'
  AND NOT EXISTS (SELECT 1 FROM warranty w
                  WHERE w.serial_id = s.serial_id AND w.status = 'ACTIVE'
                    AND CURRENT_DATE BETWEEN w.start_date AND w.end_date);
```

## 7. Monthly sales with running total (CTE + window)

```sql
WITH monthly AS (
  SELECT DATE_FORMAT(purchase_date, '%Y-%m') AS sale_month, SUM(total_amount) AS revenue
  FROM purchase GROUP BY sale_month
)
SELECT sale_month, revenue, SUM(revenue) OVER (ORDER BY sale_month) AS cumulative_revenue
FROM monthly;
```

## 8. Full-text search on complaints

```sql
SELECT request_id, MATCH(issue_description) AGAINST ('battery drains shuts down') AS relevance
FROM service_request
WHERE MATCH(issue_description) AGAINST ('battery drains shuts down')
ORDER BY relevance DESC;
```

## 9. Vector similarity (PostgreSQL)

```sql
SELECT request_id, 1 - (embedding <=> $1::vector) AS similarity
FROM issue_embedding
WHERE product_category = $2
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

## Index use (EXPLAIN)

- `idx_serial_model_mfg` is used for recall matching: `type = range, Extra = Using where; Using index`.
- `idx_issue_embedding_hnsw` is used for vector search: `Index Scan using idx_issue_embedding_hnsw`.
