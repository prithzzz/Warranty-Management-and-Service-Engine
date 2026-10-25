USE warranty_engine;

-- DML 1 (INSERT via procedure): auto-assign technicians to open requests
CALL sp_assign_technician(12, @t12);   -- fridge, HIGH priority, Jayanagar
CALL sp_assign_technician(13, @t13);   -- laptop, LOW priority, Whitefield
SELECT 12 AS request_id, @t12 AS technician_id, (SELECT full_name FROM technician WHERE technician_id = @t12) AS name
UNION ALL
SELECT 13, @t13, (SELECT full_name FROM technician WHERE technician_id = @t13);

-- DML 2 (UPDATE + INSERT + DELETE): technician starts work on the laptop, adds a wrong part, removes it (stock is restored by trigger), adds the right one and completes the repair through the procedure
SET @r13 = (SELECT repair_id FROM repair WHERE request_id = 13);
-- part ids are looked up first: a trigger on repair_part updates spare_part, so the INSERT itself must not read spare_part
SET @battery = (SELECT part_id FROM spare_part WHERE part_code = 'PRT-BAT-INS');
SET @hinge   = (SELECT part_id FROM spare_part WHERE part_code = 'PRT-HNG-INS');

UPDATE repair SET status = 'IN_PROGRESS' WHERE repair_id = @r13;

INSERT INTO repair_part (repair_id, part_id, quantity, unit_price)
VALUES (@r13, @battery, 1, NULL);

DELETE FROM repair_part
WHERE repair_id = @r13
  AND part_id = @battery;

INSERT INTO repair_part (repair_id, part_id, quantity, unit_price)
VALUES (@r13, @hinge, 1, NULL);

CALL sp_file_warranty_claim(13, 'REPAIR', @claim13);
UPDATE warranty_claim SET status = 'APPROVED' WHERE claim_id = @claim13;
CALL sp_complete_repair(@r13, 400.00, 'Hinge kit replaced and screws re-torqued');

SELECT sr.request_id, sr.status AS request_status, wc.status AS claim_status,
       wc.approved_amount, fn_repair_cost(@r13) AS repair_cost
FROM service_request sr
JOIN warranty_claim wc ON wc.request_id = sr.request_id
WHERE sr.request_id = 13;

-- DML 3 (UPDATE): staff closes completed jobs once the customer collects
UPDATE service_request
SET status = 'CLOSED'
WHERE status = 'COMPLETED' AND closed_at < NOW() - INTERVAL 7 DAY;

-- DDL demo (CREATE, INSERT, UPDATE ... JOIN, DROP): bulk restock from a supplier delivery using a staging table that is dropped afterwards
CREATE TABLE part_restock_staging (
  part_code    VARCHAR(20) PRIMARY KEY,
  qty_received INT NOT NULL CHECK (qty_received > 0)
);

INSERT INTO part_restock_staging (part_code, qty_received)
SELECT part_code, (reorder_level * 2 - stock_qty)
FROM v_part_reorder_alert;

UPDATE spare_part sp
JOIN part_restock_staging st ON st.part_code = sp.part_code
SET sp.stock_qty = sp.stock_qty + st.qty_received;

DROP TABLE part_restock_staging;

-- REPORTING QUERIES
-- Q1 (JOIN, 7 tables): complete service history of one unit
SELECT sr.request_id, DATE(sr.request_date) AS requested, sr.issue_type, sr.status,
       t.full_name AS technician, sp.part_name, rp.quantity, rp.unit_price,
       wc.claim_type, wc.status AS claim_status
FROM serial_unit s
JOIN service_request sr     ON sr.serial_id = s.serial_id
LEFT JOIN repair r          ON r.request_id = sr.request_id
LEFT JOIN technician t      ON t.technician_id = r.technician_id
LEFT JOIN repair_part rp    ON rp.repair_id = r.repair_id
LEFT JOIN spare_part sp     ON sp.part_id = rp.part_id
LEFT JOIN warranty_claim wc ON wc.request_id = sr.request_id
WHERE s.serial_no = 'IP15-23K0008'
ORDER BY sr.request_date;

-- Q2 (GROUP BY, HAVING): centers by workload and average turnaround, only centers that handled at least 3 requests
SELECT sc.center_code, sc.city,
       COUNT(sr.request_id)                                    AS total_requests,
       SUM(sr.status IN ('OPEN','ASSIGNED','IN_PROGRESS'))     AS open_requests,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, sr.request_date, sr.closed_at)), 1) AS avg_hours_to_close
FROM service_center sc
JOIN service_request sr ON sr.center_id = sc.center_id
GROUP BY sc.center_id, sc.center_code, sc.city
HAVING total_requests >= 3
ORDER BY total_requests DESC;

-- Q3 (GROUP BY, HAVING, SUM): parts spend by category above 5000
SELECT sp.part_category,
       SUM(rp.quantity)                 AS units_used,
       SUM(rp.quantity * rp.unit_price) AS parts_value
FROM repair_part rp
JOIN spare_part sp ON sp.part_id = rp.part_id
GROUP BY sp.part_category
HAVING parts_value > 5000
ORDER BY parts_value DESC;

-- Q4 (subqueries): technicians whose billed labour is above the average of technicians who have done at least one job
SELECT full_name, center_code, labour_billed
FROM v_technician_performance
WHERE labour_billed > (SELECT AVG(labour_billed) FROM v_technician_performance WHERE total_jobs > 0)
ORDER BY labour_billed DESC;

-- Q5 (NOT EXISTS): active technicians with no job yet, candidates for the next assignment drive
SELECT t.full_name, sc.center_code, t.specialization
FROM technician t
JOIN service_center sc ON sc.center_id = t.center_id
WHERE t.is_active
  AND NOT EXISTS (SELECT 1 FROM repair r WHERE r.technician_id = t.technician_id);

-- Q6 (CASE in aggregates): claim outcomes by warranty plan type
SELECT wp.plan_type,
       COUNT(*)                                   AS claims,
       SUM(wc.status = 'SETTLED')                 AS settled,
       SUM(wc.status = 'REJECTED')                AS rejected,
       SUM(wc.status IN ('SUBMITTED','APPROVED')) AS pending,
       COALESCE(SUM(wc.approved_amount), 0)       AS amount_paid
FROM warranty_claim wc
JOIN warranty w       ON w.warranty_id = wc.warranty_id
JOIN warranty_plan wp ON wp.plan_id = w.plan_id
GROUP BY wp.plan_type
ORDER BY amount_paid DESC;

-- Q7 (scalar subqueries across both modules): model reliability, i.e. service requests per 100 units sold
SELECT pm.model_name,
       (SELECT COUNT(*) FROM purchase_item pi JOIN serial_unit s ON s.serial_id = pi.serial_id
         WHERE s.model_id = pm.model_id)                                     AS units_sold,
       (SELECT COUNT(*) FROM service_request sr JOIN serial_unit s ON s.serial_id = sr.serial_id
         WHERE s.model_id = pm.model_id AND sr.issue_type <> 'RECALL_FIX')   AS fault_requests
FROM product_model pm
HAVING units_sold > 0
ORDER BY fault_requests / units_sold DESC;

-- Q8 (window function LAG): repeat visits, i.e. the same unit back within 365 days of its previous request
SELECT serial_no, request_id, request_date, prev_request_date,
       DATEDIFF(request_date, prev_request_date) AS days_since_last
FROM (
  SELECT s.serial_no, sr.request_id, sr.request_date,
         LAG(sr.request_date) OVER (PARTITION BY sr.serial_id ORDER BY sr.request_date) AS prev_request_date
  FROM service_request sr
  JOIN serial_unit s ON s.serial_id = sr.serial_id
) AS v
WHERE prev_request_date IS NOT NULL
  AND DATEDIFF(request_date, prev_request_date) <= 365;

-- Q9 (FULL-TEXT): find past requests similar to a new complaint
SELECT request_id, issue_type,
       LEFT(issue_description, 60) AS description,
       MATCH(issue_description) AGAINST ('battery drains shuts down') AS relevance
FROM service_request
WHERE MATCH(issue_description) AGAINST ('battery drains shuts down')
ORDER BY relevance DESC;

SELECT request_id, LEFT(issue_description, 70) AS description
FROM service_request
WHERE MATCH(issue_description) AGAINST ('+screen -water' IN BOOLEAN MODE);

-- Q10 (audit trail): every status change of the replacement request
SELECT request_id, old_status, new_status, changed_at
FROM service_status_log
WHERE request_id = 11
ORDER BY log_id;

-- Q11 (view): today's open queue, most urgent first
SELECT request_id, center_code, priority, status, customer_name, model_name,
       technician_name, under_warranty
FROM v_open_service_queue
ORDER BY FIELD(priority, 'URGENT','HIGH','MEDIUM','LOW'), age_hours DESC;

-- Q12 (EXPLAIN): queue filtering uses idx_sr_status_priority
EXPLAIN
SELECT request_id FROM service_request
WHERE status = 'OPEN' AND priority = 'HIGH';
