-- =====================================================================
-- sales_module/queries.sql
-- Sales, Warranty and Recall module
-- DML (INSERT/UPDATE/DELETE via procedures and direct statements) and
-- reporting queries: JOIN, GROUP BY, HAVING, ORDER BY, aggregates,
-- subqueries, CTE, window functions, full-text search, EXPLAIN
-- =====================================================================
USE warranty_engine;

-- ---------------------------------------------------------------------
-- DML 1 (INSERT through a transaction): a new customer buys an iPhone 16
-- ---------------------------------------------------------------------
INSERT INTO customer (full_name, email, phone, address, city, preferred_channel)
VALUES ('Ishaan Kapoor', 'ishaan.kapoor@mail.com', '9811012313', '5 RT Nagar Main Rd', 'Bengaluru', 'APP');

CALL sp_register_sale(LAST_INSERT_ID(), 'INV-2026-0020', CURRENT_DATE, 'ONLINE',
                      'IP16-24L0012', 74900.00, 'STD12', @new_purchase);
SELECT @new_purchase AS new_purchase_id;

-- ---------------------------------------------------------------------
-- DML 2 (UPDATE): customer changes phone number and alert channel
-- ---------------------------------------------------------------------
UPDATE customer
SET phone = '9811099913', preferred_channel = 'SMS'
WHERE email = 'ishaan.kapoor@mail.com';

-- ---------------------------------------------------------------------
-- DML 3 (INSERT then DELETE): a sale that is returned within 7 days.
-- Deleting the item fires trg_purchase_item_ad which voids the warranty
-- and puts the unit back in stock; the empty invoice is then removed.
-- ---------------------------------------------------------------------
CALL sp_register_sale(6, 'INV-2026-0021', CURRENT_DATE, 'RETAIL_STORE',
                      'XM5-23H0029', 22990.00, 'STD12', @ret_purchase);

DELETE FROM purchase_item WHERE purchase_id = @ret_purchase;
DELETE FROM purchase
WHERE purchase_id = @ret_purchase
  AND NOT EXISTS (SELECT 1 FROM purchase_item pi WHERE pi.purchase_id = purchase.purchase_id);

SELECT s.serial_no, s.status AS unit_status, w.status AS warranty_status
FROM serial_unit s LEFT JOIN warranty w ON w.serial_id = s.serial_id
WHERE s.serial_no = 'XM5-23H0029';

-- ---------------------------------------------------------------------
-- DML 4 (procedure): activate the Inspiron adapter recall and notify owners
-- ---------------------------------------------------------------------
CALL sp_generate_recall_notifications(
  (SELECT recall_id FROM recall_campaign WHERE recall_code = 'RC-2025-003'), @created);
SELECT @created AS notifications_created;

-- ---------------------------------------------------------------------
-- DML 5 (UPDATE with subquery): close any active recall whose every
-- notification is RESOLVED
-- ---------------------------------------------------------------------
UPDATE recall_campaign rc
SET rc.status = 'CLOSED'
WHERE rc.status = 'ACTIVE'
  AND EXISTS     (SELECT 1 FROM recall_notification n WHERE n.recall_id = rc.recall_id)
  AND NOT EXISTS (SELECT 1 FROM recall_notification n
                  WHERE n.recall_id = rc.recall_id AND n.status <> 'RESOLVED');

-- =====================================================================
-- REPORTING QUERIES
-- =====================================================================

-- Q1 (JOIN, 5 tables): full purchase history of a customer
SELECT c.full_name, p.invoice_no, p.purchase_date, p.channel,
       pr.brand, pm.model_name, s.serial_no, pi.unit_price
FROM customer c
JOIN purchase p       ON p.customer_id = c.customer_id
JOIN purchase_item pi ON pi.purchase_id = p.purchase_id
JOIN serial_unit s    ON s.serial_id = pi.serial_id
JOIN product_model pm ON pm.model_id = s.model_id
JOIN product pr       ON pr.product_id = pm.product_id
WHERE c.email = 'ananya.sharma@mail.com'
ORDER BY p.purchase_date DESC;

-- Q2 (GROUP BY, HAVING, aggregates): revenue by brand and category,
-- only combinations above 1 lakh
SELECT pr.brand, pr.category,
       COUNT(*)            AS units_sold,
       SUM(pi.unit_price)  AS revenue,
       ROUND(AVG(pi.unit_price), 2) AS avg_selling_price
FROM purchase_item pi
JOIN serial_unit s    ON s.serial_id = pi.serial_id
JOIN product_model pm ON pm.model_id = s.model_id
JOIN product pr       ON pr.product_id = pm.product_id
GROUP BY pr.brand, pr.category
HAVING revenue > 100000
ORDER BY revenue DESC;

-- Q3 (subquery in HAVING): customers who spent more than the average customer
SELECT c.customer_id, c.full_name, SUM(p.total_amount) AS lifetime_spend
FROM customer c
JOIN purchase p ON p.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
HAVING lifetime_spend > (SELECT AVG(t.spend)
                         FROM (SELECT SUM(total_amount) AS spend
                               FROM purchase GROUP BY customer_id) AS t)
ORDER BY lifetime_spend DESC;

-- Q4 (correlated NOT EXISTS): sold units with no live warranty today,
-- the target list for an extended warranty offer
SELECT c.full_name, c.email, s.serial_no, pm.model_name
FROM serial_unit s
JOIN customer c       ON c.customer_id = s.current_owner_id
JOIN product_model pm ON pm.model_id = s.model_id
WHERE s.status = 'SOLD'
  AND NOT EXISTS (SELECT 1 FROM warranty w
                  WHERE w.serial_id = s.serial_id
                    AND w.status = 'ACTIVE'
                    AND CURRENT_DATE BETWEEN w.start_date AND w.end_date)
ORDER BY c.full_name;

-- Q5 (window function): rank models by units sold within each category
SELECT category, model_name, units_sold,
       RANK() OVER (PARTITION BY category ORDER BY units_sold DESC) AS rank_in_category
FROM (
  SELECT pr.category, pm.model_name, COUNT(pi.purchase_item_id) AS units_sold
  FROM product_model pm
  JOIN product pr            ON pr.product_id = pm.product_id
  LEFT JOIN serial_unit s    ON s.model_id = pm.model_id
  LEFT JOIN purchase_item pi ON pi.serial_id = s.serial_id
  GROUP BY pr.category, pm.model_name
) AS m
ORDER BY category, rank_in_category;

-- Q6 (CTE + running total): monthly sales trend
WITH monthly AS (
  SELECT DATE_FORMAT(purchase_date, '%Y-%m') AS sale_month,
         COUNT(*) AS invoices, SUM(total_amount) AS revenue
  FROM purchase
  GROUP BY sale_month
)
SELECT sale_month, invoices, revenue,
       SUM(revenue) OVER (ORDER BY sale_month) AS cumulative_revenue
FROM monthly
ORDER BY sale_month;

-- Q7 (view): warranties expiring within the next 120 days
SELECT customer_name, serial_no, model_name, plan_code, end_date, days_left
FROM v_warranty_overview
WHERE live_status IN ('ACTIVE','EXPIRING_SOON') AND days_left <= 120
ORDER BY days_left;

-- Q8 (aggregation with CASE): recall progress report
SELECT rc.recall_code, rc.title, rc.status,
       COUNT(n.notification_id)                       AS owners_notified,
       SUM(n.status = 'ACKNOWLEDGED')                 AS acknowledged,
       SUM(n.status = 'RESOLVED')                     AS resolved,
       ROUND(100 * SUM(n.status = 'RESOLVED') / NULLIF(COUNT(n.notification_id), 0), 1) AS pct_resolved
FROM recall_campaign rc
LEFT JOIN recall_notification n ON n.recall_id = rc.recall_id
GROUP BY rc.recall_id, rc.recall_code, rc.title, rc.status
ORDER BY rc.announced_on;

-- Q9 (FULL-TEXT, natural language and boolean mode): search recall notices
SELECT recall_code, title,
       MATCH(title, reason) AGAINST ('battery swelling') AS relevance
FROM recall_campaign
WHERE MATCH(title, reason) AGAINST ('battery swelling')
ORDER BY relevance DESC;

SELECT recall_code, title
FROM recall_campaign
WHERE MATCH(title, reason) AGAINST ('+charging -refrigerator' IN BOOLEAN MODE);

-- Q10 (functions): is a given unit covered today, and is it under recall?
SELECT s.serial_no,
       fn_has_active_warranty(s.serial_id, CURRENT_DATE) AS covered_today,
       rc.recall_code AS active_recall
FROM serial_unit s
LEFT JOIN recall_campaign rc ON rc.recall_id = fn_unit_under_recall(s.serial_id)
WHERE s.serial_no IN ('S24-24A0002', 'INS54-24C0015', 'LGC4-24D0019');

-- Q11 (EXPLAIN): the recall lookup uses idx_serial_model_mfg
EXPLAIN
SELECT serial_id FROM serial_unit
WHERE model_id = 1 AND manufacture_date BETWEEN '2024-02-01' AND '2024-04-30';
