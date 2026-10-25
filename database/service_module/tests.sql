USE warranty_engine;
DELETE FROM test_result WHERE owner = 'B';

SET @priya_iphone = (SELECT serial_id FROM serial_unit WHERE serial_no = 'IP16-24L0011');  -- owner 3, EXT36 active
SET @in_stock     = (SELECT serial_id FROM serial_unit WHERE serial_no = 'S25-25A0007');
SET @fridge_oow   = (SELECT serial_id FROM serial_unit WHERE serial_no = 'LGFR-23E0023'); -- owner 9
SET @mys          = (SELECT center_id FROM service_center WHERE center_code = 'MYS-01');
SET @blr_jn       = (SELECT center_id FROM service_center WHERE center_code = 'BLR-JN');
SET @recall_s24   = (SELECT recall_id FROM recall_campaign WHERE recall_code = 'RC-2024-001');
SET @ext36_priya  = (SELECT warranty_id FROM warranty WHERE serial_id = @priya_iphone AND status = 'ACTIVE' LIMIT 1);
SET @tech_chennai = (SELECT technician_id FROM technician WHERE full_name = 'Karthik Subramanian');
SET @settled      = (SELECT claim_id FROM warranty_claim WHERE status = 'SETTLED' LIMIT 1);
SET @submitted    = (SELECT claim_id FROM warranty_claim WHERE status = 'SUBMITTED' LIMIT 1);
SET @closed_req   = (SELECT request_id FROM service_request WHERE status = 'CLOSED' LIMIT 1);
SET @low_part     = (SELECT part_id FROM spare_part WHERE part_code = 'PRT-PNL-C4');
SET @open_repair  = (SELECT repair_id FROM repair WHERE status = 'IN_PROGRESS' LIMIT 1);

-- service request rules
CALL sp_expect_error('B', 'T01 only the owner can raise a service request',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, issue_description) VALUES (1, @priya_iphone, @mys, "HARDWARE", "Someone else phone is broken")');
CALL sp_expect_error('B', 'T02 unsold unit cannot get a service request',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, issue_description) VALUES (1, @in_stock, @mys, "HARDWARE", "Unit was never sold to anyone")');
CALL sp_expect_error('B', 'T03 recall request must be for a unit in that recall',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, recall_id, issue_description) VALUES (3, @priya_iphone, @mys, "RECALL_FIX", @recall_s24, "Recall fix for a phone outside the scope")');
CALL sp_expect_error('B', 'T04 issue description needs at least 10 characters',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, issue_description) VALUES (3, @priya_iphone, @mys, "HARDWARE", "broken")');
CALL sp_expect_error('B', 'T05 RECALL_FIX requires a recall id',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, issue_description) VALUES (3, @priya_iphone, @mys, "RECALL_FIX", "Recall fix with no recall linked")');
CALL sp_expect_error('B', 'T06 closed request cannot be reopened',
  'UPDATE service_request SET status = "IN_PROGRESS" WHERE request_id = @closed_req');

-- repair and inventory rules
CALL sp_expect_error('B', 'T07 technician must belong to the request center',
  'INSERT INTO repair (request_id, technician_id) VALUES ((SELECT request_id FROM service_request WHERE status = "ASSIGNED" LIMIT 1), @tech_chennai)');
CALL sp_expect_error('B', 'T08 cannot use more parts than in stock',
  'INSERT INTO repair_part (repair_id, part_id, quantity, unit_price) VALUES (@open_repair, @low_part, 500, NULL)');
CALL sp_expect_error('B', 'T09 stock can never be negative',
  'UPDATE spare_part SET stock_qty = -1 WHERE part_id = @low_part');

-- claim rules
CALL sp_expect_error('B', 'T10 claim outside warranty period is refused',
  'CALL sp_file_warranty_claim(9, "REPAIR", @x)');
CALL sp_expect_ok('B', 'T11 setup: new physical damage request for an EXT36 phone',
  'INSERT INTO service_request (customer_id, serial_id, center_id, issue_type, issue_description) VALUES (3, @priya_iphone, @mys, "PHYSICAL_DAMAGE", "Screen cracked after the phone slipped")');
SET @dmg_req = (SELECT MAX(request_id) FROM service_request);
CALL sp_expect_error('B', 'T12 physical damage cannot be claimed on an extended plan (procedure)',
  'CALL sp_file_warranty_claim(@dmg_req, "REPAIR", @x)');
CALL sp_expect_error('B', 'T13 physical damage cannot be claimed on an extended plan (direct insert)',
  'INSERT INTO warranty_claim (warranty_id, request_id, claim_date, claim_type) VALUES (@ext36_priya, @dmg_req, CURRENT_DATE, "REPAIR")');
CALL sp_expect_error('B', 'T14 only one claim per request',
  'INSERT INTO warranty_claim (warranty_id, request_id, claim_date, claim_type) SELECT warranty_id, request_id, claim_date, claim_type FROM warranty_claim WHERE claim_id = @settled');
CALL sp_expect_error('B', 'T15 a submitted claim cannot jump to SETTLED',
  'UPDATE warranty_claim SET status = "SETTLED", approved_amount = 100 WHERE claim_id = @submitted');
CALL sp_expect_error('B', 'T16 a settled claim is final',
  'UPDATE warranty_claim SET status = "REJECTED" WHERE claim_id = @settled');

-- replacement transaction rolls back on a bad unit
CALL sp_expect_ok('B', 'T17 setup: replacement claim for request 14 filed and approved',
  'CALL sp_file_warranty_claim(14, "REPLACEMENT", @rc14)');
UPDATE warranty_claim SET status = 'APPROVED' WHERE request_id = 14;
CALL sp_expect_error('B', 'T18 replacement with a different model is refused',
  'CALL sp_process_replacement(@rc14, "S25-25A0007")');
CALL sp_assert('B', 'T19 failed replacement changed nothing (claim APPROVED, unit IN_STOCK, no replacement row)',
  '(SELECT status FROM warranty_claim WHERE claim_id = @rc14) = "APPROVED" AND (SELECT status FROM serial_unit WHERE serial_id = @in_stock) = "IN_STOCK" AND NOT EXISTS (SELECT 1 FROM replacement WHERE claim_id = @rc14)');

-- login accounts
CALL sp_expect_error('B', 'T20 customer login must link to a customer record',
  'INSERT INTO app_user (username, email, password_hash, role) VALUES ("ghost", "ghost@mail.com", "$2b$10$yp9QgjK9bvRf3hdkL51b/ufzasqAglQcqdAKDZz2B1cHXdeu/R1Ca", "CUSTOMER")');
CALL sp_expect_error('B', 'T21 plain text passwords are rejected',
  'INSERT INTO app_user (username, email, password_hash, role) VALUES ("admin2", "admin2@wmse.in", "Password@123", "ADMIN")');

-- positive path: assignment, stock and audit trail
CALL sp_expect_ok('B', 'T22 technician auto-assignment works',
  'CALL sp_assign_technician(@dmg_req, @dmg_tech)');
CALL sp_assert('B', 'T23 assigned technician is from the same center and request moved to ASSIGNED',
  '(SELECT center_id FROM technician WHERE technician_id = @dmg_tech) = @mys AND (SELECT status FROM service_request WHERE request_id = @dmg_req) = "ASSIGNED"');
CALL sp_assert('B', 'T24 every status change was logged',
  '(SELECT COUNT(*) FROM service_status_log WHERE request_id = @dmg_req) = 2');
CALL sp_assert('B', 'T25 repair cost function equals labour plus parts',
  'fn_repair_cost(1) = (SELECT labour_charge FROM repair WHERE repair_id = 1) + (SELECT SUM(quantity * unit_price) FROM repair_part WHERE repair_id = 1)');

SELECT test_id, test_name, expected, outcome, message FROM test_result WHERE owner = 'B' ORDER BY test_id;
