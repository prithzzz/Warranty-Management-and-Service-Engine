-- =====================================================================
-- sales_module/tests.sql
-- Integrity and business-rule tests for the Sales, Warranty and Recall module
-- Run after common/test_framework.sql. Inner string literals use double quotes.
-- =====================================================================
USE warranty_engine;
DELETE FROM test_result WHERE owner = 'SALES';

SET @sold_unit    = (SELECT serial_id FROM serial_unit WHERE serial_no = 'S24-24B0004');
SET @stock_unit   = (SELECT serial_id FROM serial_unit WHERE serial_no = 'S25-25A0007');
SET @std12        = (SELECT plan_id FROM warranty_plan WHERE plan_code = 'STD12');
SET @inv1         = (SELECT purchase_id FROM purchase WHERE invoice_no = 'INV-2023-0001');
SET @inv_recent   = (SELECT purchase_id FROM purchase WHERE invoice_no = 'INV-2026-0019');

-- data validation (CHECK, UNIQUE, NOT NULL)
CALL sp_expect_error('SALES', 'T01 customer email format is validated',
  'INSERT INTO customer (full_name, email, phone, city) VALUES ("Test User", "not-an-email", "9000000001", "Bengaluru")');
CALL sp_expect_error('SALES', 'T02 customer phone must be a 10 digit Indian mobile',
  'INSERT INTO customer (full_name, email, phone, city) VALUES ("Test User", "t02@mail.com", "12345", "Bengaluru")');
CALL sp_expect_error('SALES', 'T03 duplicate customer email is rejected',
  'INSERT INTO customer (full_name, email, phone, city) VALUES ("Copy", "ananya.sharma@mail.com", "9000000003", "Bengaluru")');
CALL sp_expect_error('SALES', 'T04 sale price must be positive',
  'INSERT INTO purchase_item (purchase_id, serial_id, unit_price) VALUES (@inv_recent, @stock_unit, -10)');
CALL sp_expect_error('SALES', 'T05 warranty plan duration must be 1 to 60 months',
  'INSERT INTO warranty_plan (plan_code, plan_name, plan_type, duration_months, coverage_desc) VALUES ("BAD0", "Bad", "STANDARD", 0, "x")');
CALL sp_expect_error('SALES', 'T06 recall scope date range must be valid',
  'INSERT INTO recall_scope (recall_id, model_id, mfg_from, mfg_to) VALUES (1, 1, "2024-05-01", "2024-01-01")');

-- referential integrity
CALL sp_expect_error('SALES', 'T07 customer with purchases cannot be deleted',
  'DELETE FROM customer WHERE email = "divya.krishnan@mail.com"');
CALL sp_expect_error('SALES', 'T08 product model must reference an existing product',
  'INSERT INTO product_model (product_id, model_code, model_name, launch_date, mrp) VALUES (999, "X1", "Ghost", "2025-01-01", 100)');

-- trigger business rules
CALL sp_expect_error('SALES', 'T09 an already sold unit cannot be sold again',
  'INSERT INTO purchase_item (purchase_id, serial_id, unit_price) VALUES (@inv1, @sold_unit, 50000)');
CALL sp_expect_error('SALES', 'T10 purchase date cannot be before manufacture date',
  'CALL sp_register_sale(1, "INV-T10", "2020-01-01", "ONLINE", "S25-25A0007", 70000, "STD12", @x)');
CALL sp_expect_error('SALES', 'T11 unit under an active recall cannot be sold',
  'CALL sp_register_sale(1, "INV-T11", CURRENT_DATE, "ONLINE", "S24-24A0005", 70000, "STD12", @x)');
CALL sp_expect_error('SALES', 'T12 warranty cannot be issued for an unsold unit',
  'INSERT INTO warranty (serial_id, plan_id, start_date, end_date) VALUES (@stock_unit, @std12, CURRENT_DATE, NULL)');
CALL sp_expect_error('SALES', 'T13 overlapping warranty of the same type is blocked',
  'INSERT INTO warranty (serial_id, plan_id, start_date, end_date) SELECT serial_id, plan_id, start_date + INTERVAL 1 DAY, NULL FROM (SELECT serial_id, plan_id, start_date FROM warranty WHERE status = "ACTIVE" LIMIT 1) AS w');

-- transactions: a failed sale leaves no partial rows behind
CALL sp_expect_error('SALES', 'T14 sale with unknown plan code fails',
  'CALL sp_register_sale(1, "INV-T14", CURRENT_DATE, "ONLINE", "S25-25A0007", 70000, "NOPLAN", @x)');
CALL sp_assert('SALES', 'T15 failed sale rolled back completely (no invoice, unit still in stock)',
  'NOT EXISTS (SELECT 1 FROM purchase WHERE invoice_no = "INV-T14") AND (SELECT status FROM serial_unit WHERE serial_no = "S25-25A0007") = "IN_STOCK"');

-- positive path
CALL sp_expect_ok('SALES', 'T16 valid sale with warranty succeeds',
  'CALL sp_register_sale(3, "INV-T16", CURRENT_DATE, "DEALER", "LGC4-24D0020", 119990, "STD24", @x)');
CALL sp_assert('SALES', 'T17 sale trigger set owner, invoice total and 24 month end date',
  '(SELECT current_owner_id FROM serial_unit WHERE serial_no = "LGC4-24D0020") = 3 AND (SELECT total_amount FROM purchase WHERE invoice_no = "INV-T16") = 119990 AND (SELECT w.end_date FROM warranty w JOIN serial_unit s ON s.serial_id = w.serial_id WHERE s.serial_no = "LGC4-24D0020") = CURRENT_DATE + INTERVAL 24 MONTH');
CALL sp_expect_ok('SALES', 'T18 recall notification job can be re-run',
  'CALL sp_generate_recall_notifications(2, @again)');
CALL sp_assert('SALES', 'T19 re-run created no duplicate notifications', '@again = 0');
CALL sp_assert('SALES', 'T20 functions report coverage and recall correctly',
  'fn_has_active_warranty((SELECT serial_id FROM serial_unit WHERE serial_no = "IP16-24L0011"), CURRENT_DATE) = 1 AND fn_unit_under_recall((SELECT serial_id FROM serial_unit WHERE serial_no = "S24-24A0005")) IS NOT NULL');

SELECT test_id, test_name, expected, outcome, message FROM test_result WHERE owner = 'SALES' ORDER BY test_id;
