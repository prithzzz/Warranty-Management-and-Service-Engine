USE warranty_engine;

DROP FUNCTION  IF EXISTS fn_repair_cost;
DROP PROCEDURE IF EXISTS sp_assign_technician;
DROP PROCEDURE IF EXISTS sp_file_warranty_claim;
DROP PROCEDURE IF EXISTS sp_complete_repair;
DROP PROCEDURE IF EXISTS sp_process_replacement;
DROP TRIGGER   IF EXISTS trg_sr_bi;
DROP TRIGGER   IF EXISTS trg_sr_ai;
DROP TRIGGER   IF EXISTS trg_sr_bu;
DROP TRIGGER   IF EXISTS trg_sr_au;
DROP TRIGGER   IF EXISTS trg_repair_bi;
DROP TRIGGER   IF EXISTS trg_repair_ai;
DROP TRIGGER   IF EXISTS trg_repair_au;
DROP TRIGGER   IF EXISTS trg_repair_part_bi;
DROP TRIGGER   IF EXISTS trg_repair_part_ai;
DROP TRIGGER   IF EXISTS trg_repair_part_ad;
DROP TRIGGER   IF EXISTS trg_claim_bi;
DROP TRIGGER   IF EXISTS trg_claim_bu;

DELIMITER $$

-- total cost of a repair = labour + parts used
CREATE FUNCTION fn_repair_cost(p_repair_id INT) RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
  DECLARE v_labour DECIMAL(12,2) DEFAULT 0;
  DECLARE v_parts  DECIMAL(12,2) DEFAULT 0;
  SELECT labour_charge INTO v_labour FROM repair WHERE repair_id = p_repair_id;
  SELECT COALESCE(SUM(quantity * unit_price), 0) INTO v_parts
  FROM repair_part WHERE repair_id = p_repair_id;
  RETURN COALESCE(v_labour, 0) + v_parts;
END$$

-- only the current owner of a sold unit can raise a request, and a recall request must be for a unit inside that recall's scope
CREATE TRIGGER trg_sr_bi
BEFORE INSERT ON service_request
FOR EACH ROW
BEGIN
  DECLARE v_owner INT;
  DECLARE v_status VARCHAR(20);

  SELECT current_owner_id, status INTO v_owner, v_status
  FROM serial_unit WHERE serial_id = NEW.serial_id;

  IF v_status <> 'SOLD' OR v_owner IS NULL OR v_owner <> NEW.customer_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Service can only be requested by the current owner of a sold unit';
  END IF;

  IF NEW.recall_id IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM recall_scope rs
      JOIN serial_unit s ON s.model_id = rs.model_id
                        AND s.manufacture_date BETWEEN rs.mfg_from AND rs.mfg_to
      WHERE rs.recall_id = NEW.recall_id AND s.serial_id = NEW.serial_id) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unit is not covered by the given recall';
  END IF;
END$$

CREATE TRIGGER trg_sr_ai
AFTER INSERT ON service_request
FOR EACH ROW
BEGIN
  INSERT INTO service_status_log (request_id, old_status, new_status, changed_by)
  VALUES (NEW.request_id, NULL, NEW.status, CURRENT_USER());
END$$

-- status workflow rules
CREATE TRIGGER trg_sr_bu
BEFORE UPDATE ON service_request
FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    IF OLD.status IN ('CLOSED','CANCELLED') THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A closed or cancelled request cannot change status';
    END IF;
    IF NEW.status = 'OPEN' THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A request cannot be moved back to OPEN';
    END IF;
    IF NEW.status IN ('COMPLETED','CLOSED','CANCELLED') AND NEW.closed_at IS NULL THEN
      SET NEW.closed_at = NOW();
    END IF;
  END IF;
END$$

-- audit trail of every status change
CREATE TRIGGER trg_sr_au
AFTER UPDATE ON service_request
FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    INSERT INTO service_status_log (request_id, old_status, new_status, changed_by)
    VALUES (NEW.request_id, OLD.status, NEW.status, CURRENT_USER());
  END IF;
END$$

-- REPAIR triggers
CREATE TRIGGER trg_repair_bi
BEFORE INSERT ON repair
FOR EACH ROW
BEGIN
  DECLARE v_req_status VARCHAR(20);
  DECLARE v_req_center INT;
  DECLARE v_tech_center INT;
  DECLARE v_tech_active BOOLEAN;

  SELECT status, center_id INTO v_req_status, v_req_center
  FROM service_request WHERE request_id = NEW.request_id;
  SELECT center_id, is_active INTO v_tech_center, v_tech_active
  FROM technician WHERE technician_id = NEW.technician_id;

  IF v_req_status IN ('COMPLETED','CLOSED','CANCELLED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot start a repair on a finished request';
  END IF;
  IF v_tech_center <> v_req_center OR NOT v_tech_active THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Technician must be active and belong to the request service center';
  END IF;
END$$

-- request moves forward when a repair is opened
CREATE TRIGGER trg_repair_ai
AFTER INSERT ON repair
FOR EACH ROW
BEGIN
  UPDATE service_request
  SET status = IF(NEW.status = 'ASSIGNED', 'ASSIGNED', 'IN_PROGRESS')
  WHERE request_id = NEW.request_id AND status = 'OPEN';
END$$

-- repair progress drives request status and settles approved repair claims
CREATE TRIGGER trg_repair_au
AFTER UPDATE ON repair
FOR EACH ROW
BEGIN
  IF NEW.status <> OLD.status THEN
    IF NEW.status = 'IN_PROGRESS' THEN
      UPDATE service_request SET status = 'IN_PROGRESS'
      WHERE request_id = NEW.request_id AND status IN ('OPEN','ASSIGNED');
    ELSEIF NEW.status = 'COMPLETED' THEN
      UPDATE service_request
      SET status = 'COMPLETED', closed_at = NEW.completed_at
      WHERE request_id = NEW.request_id AND status IN ('OPEN','ASSIGNED','IN_PROGRESS');

      UPDATE warranty_claim
      SET status = 'SETTLED', approved_amount = fn_repair_cost(NEW.repair_id)
      WHERE request_id = NEW.request_id AND claim_type = 'REPAIR' AND status = 'APPROVED';
    END IF;
  END IF;
END$$

-- REPAIR_PART triggers: stock can never go negative
CREATE TRIGGER trg_repair_part_bi
BEFORE INSERT ON repair_part
FOR EACH ROW
BEGIN
  DECLARE v_stock INT;
  DECLARE v_price DECIMAL(10,2);
  DECLARE v_repair_status VARCHAR(20);

  SELECT status INTO v_repair_status FROM repair WHERE repair_id = NEW.repair_id;
  IF v_repair_status IN ('COMPLETED','FAILED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot add parts to a finished repair';
  END IF;

  SELECT stock_qty, unit_price INTO v_stock, v_price
  FROM spare_part WHERE part_id = NEW.part_id FOR UPDATE;

  IF v_stock < NEW.quantity THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient spare part stock';
  END IF;
  IF NEW.unit_price IS NULL THEN
    SET NEW.unit_price = v_price;          -- default to current catalogue price
  END IF;
END$$

CREATE TRIGGER trg_repair_part_ai
AFTER INSERT ON repair_part
FOR EACH ROW
BEGIN
  UPDATE spare_part SET stock_qty = stock_qty - NEW.quantity
  WHERE part_id = NEW.part_id;
END$$

CREATE TRIGGER trg_repair_part_ad
AFTER DELETE ON repair_part
FOR EACH ROW
BEGIN
  UPDATE spare_part SET stock_qty = stock_qty + OLD.quantity
  WHERE part_id = OLD.part_id;
END$$

-- WARRANTY_CLAIM triggers: business rules for a valid claim
CREATE TRIGGER trg_claim_bi
BEFORE INSERT ON warranty_claim
FOR EACH ROW
BEGIN
  DECLARE v_req_serial INT;
  DECLARE v_req_date DATE;
  DECLARE v_issue VARCHAR(20);
  DECLARE v_w_serial INT;
  DECLARE v_start DATE;
  DECLARE v_end DATE;
  DECLARE v_w_status VARCHAR(10);
  DECLARE v_plan_type VARCHAR(20);
  DECLARE v_max INT;
  DECLARE v_used INT;

  SELECT serial_id, DATE(request_date), issue_type
    INTO v_req_serial, v_req_date, v_issue
  FROM service_request WHERE request_id = NEW.request_id;

  SELECT w.serial_id, w.start_date, w.end_date, w.status, wp.plan_type, wp.max_claims
    INTO v_w_serial, v_start, v_end, v_w_status, v_plan_type, v_max
  FROM warranty w JOIN warranty_plan wp ON wp.plan_id = w.plan_id
  WHERE w.warranty_id = NEW.warranty_id;

  IF NEW.claim_date IS NULL THEN
    SET NEW.claim_date = CURRENT_DATE;
  END IF;

  IF v_w_serial <> v_req_serial THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Warranty does not belong to the unit in this request';
  END IF;
  IF v_w_status = 'VOID' OR v_req_date NOT BETWEEN v_start AND v_end THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Request date is outside the warranty period';
  END IF;
  IF (v_issue = 'PHYSICAL_DAMAGE') <> (v_plan_type = 'ACCIDENTAL_DAMAGE') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Physical damage needs an accidental damage plan, other faults need a standard or extended plan';
  END IF;

  SELECT COUNT(*) INTO v_used FROM warranty_claim
  WHERE warranty_id = NEW.warranty_id AND status <> 'REJECTED';
  IF v_used >= v_max THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maximum number of claims for this warranty reached';
  END IF;
END$$

-- REJECTED and SETTLED are final states
CREATE TRIGGER trg_claim_bu
BEFORE UPDATE ON warranty_claim
FOR EACH ROW
BEGIN
  IF OLD.status IN ('REJECTED','SETTLED') AND NEW.status <> OLD.status THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A rejected or settled claim cannot change status';
  END IF;
  IF OLD.status = 'SUBMITTED' AND NEW.status = 'SETTLED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A claim must be approved before it is settled';
  END IF;
END$$

-- PROCEDURE (TRANSACTION): auto-assign the best technician.
-- Rule: same center, matching specialization first, then fewest open jobs, then experts for HIGH/URGENT work and juniors for the rest.
CREATE PROCEDURE sp_assign_technician(
  IN  p_request_id    INT,
  OUT p_technician_id INT)
BEGIN
  DECLARE v_center   INT;
  DECLARE v_category VARCHAR(20);
  DECLARE v_priority VARCHAR(10);
  DECLARE v_status   VARCHAR(20);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT sr.center_id, p.category, sr.priority, sr.status
    INTO v_center, v_category, v_priority, v_status
  FROM service_request sr
  JOIN serial_unit s    ON s.serial_id = sr.serial_id
  JOIN product_model pm ON pm.model_id = s.model_id
  JOIN product p        ON p.product_id = pm.product_id
  WHERE sr.request_id = p_request_id
  FOR UPDATE;

  IF v_status IS NULL OR v_status <> 'OPEN' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an existing OPEN request can be assigned';
  END IF;

  SET p_technician_id = NULL;
  SELECT t.technician_id INTO p_technician_id
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

  IF p_technician_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No active technician available at this center';
  END IF;

  INSERT INTO repair (request_id, technician_id, status)
  VALUES (p_request_id, p_technician_id, 'ASSIGNED');   -- trigger sets request to ASSIGNED

  COMMIT;
END$$

-- PROCEDURE (TRANSACTION): file a claim against the right warranty.
-- Picks the non-void warranty that covers the request date and the issue type (accidental plan for physical damage, otherwise standard/extended).
CREATE PROCEDURE sp_file_warranty_claim(
  IN  p_request_id INT,
  IN  p_claim_type VARCHAR(20),
  OUT p_claim_id   INT)
BEGIN
  DECLARE v_serial   INT;
  DECLARE v_date     DATE;
  DECLARE v_issue    VARCHAR(20);
  DECLARE v_warranty INT DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT serial_id, DATE(request_date), issue_type
    INTO v_serial, v_date, v_issue
  FROM service_request WHERE request_id = p_request_id FOR UPDATE;

  IF v_serial IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Service request not found';
  END IF;

  SELECT w.warranty_id INTO v_warranty
  FROM warranty w
  JOIN warranty_plan wp ON wp.plan_id = w.plan_id
  WHERE w.serial_id = v_serial
    AND w.status <> 'VOID'
    AND v_date BETWEEN w.start_date AND w.end_date
    AND (v_issue = 'PHYSICAL_DAMAGE') = (wp.plan_type = 'ACCIDENTAL_DAMAGE')
  ORDER BY w.end_date DESC
  LIMIT 1;

  IF v_warranty IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No valid warranty covers this request';
  END IF;

  INSERT INTO warranty_claim (warranty_id, request_id, claim_date, claim_type)
  VALUES (v_warranty, p_request_id, v_date, p_claim_type);
  SET p_claim_id = LAST_INSERT_ID();

  COMMIT;
END$$

-- PROCEDURE (TRANSACTION): finish a repair. Triggers then close the request and settle an approved repair claim with the final cost.
CREATE PROCEDURE sp_complete_repair(
  IN p_repair_id INT,
  IN p_labour    DECIMAL(10,2),
  IN p_notes     VARCHAR(500))
BEGIN
  DECLARE v_status VARCHAR(20);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT status INTO v_status FROM repair WHERE repair_id = p_repair_id FOR UPDATE;
  IF v_status IS NULL OR v_status NOT IN ('ASSIGNED','IN_PROGRESS') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Repair is not open';
  END IF;

  UPDATE repair
  SET status = 'COMPLETED', completed_at = NOW(),
      labour_charge = p_labour, resolution_notes = p_notes
  WHERE repair_id = p_repair_id;

  COMMIT;
END$$

-- PROCEDURE (TRANSACTION): replace a faulty unit under an approved claim.
-- Eight changes across six tables must all succeed or all roll back.
CREATE PROCEDURE sp_process_replacement(
  IN p_claim_id      INT,
  IN p_new_serial_no VARCHAR(30))
BEGIN
  DECLARE v_claim_status VARCHAR(20);
  DECLARE v_claim_type   VARCHAR(20);
  DECLARE v_request      INT;
  DECLARE v_warranty     INT;
  DECLARE v_old_serial   INT;
  DECLARE v_owner        INT;
  DECLARE v_old_model    INT;
  DECLARE v_new_serial   INT DEFAULT NULL;
  DECLARE v_new_status   VARCHAR(20);
  DECLARE v_new_model    INT;
  DECLARE v_plan         INT;
  DECLARE v_end          DATE;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT status, claim_type, request_id, warranty_id
    INTO v_claim_status, v_claim_type, v_request, v_warranty
  FROM warranty_claim WHERE claim_id = p_claim_id FOR UPDATE;

  IF v_claim_status IS NULL OR v_claim_type <> 'REPLACEMENT' OR v_claim_status <> 'APPROVED' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an approved REPLACEMENT claim can be processed';
  END IF;

  SELECT serial_id, customer_id INTO v_old_serial, v_owner
  FROM service_request WHERE request_id = v_request;

  SELECT model_id INTO v_old_model FROM serial_unit
  WHERE serial_id = v_old_serial FOR UPDATE;

  SELECT serial_id, status, model_id INTO v_new_serial, v_new_status, v_new_model
  FROM serial_unit WHERE serial_no = p_new_serial_no FOR UPDATE;

  IF v_new_serial IS NULL OR v_new_status <> 'IN_STOCK' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Replacement unit must exist and be in stock';
  END IF;
  IF v_new_model <> v_old_model THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Replacement unit must be the same model';
  END IF;
  IF fn_unit_under_recall(v_new_serial) IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Replacement unit is itself under recall';
  END IF;

  SELECT plan_id, end_date INTO v_plan, v_end FROM warranty WHERE warranty_id = v_warranty;

  -- 1. record the replacement
  INSERT INTO replacement (claim_id, old_serial_id, new_serial_id, replaced_on, notes)
  VALUES (p_claim_id, v_old_serial, v_new_serial, CURRENT_DATE, 'Processed via sp_process_replacement');
  -- 2. retire the old unit, 3. hand over the new unit
  UPDATE serial_unit SET status = 'REPLACED' WHERE serial_id = v_old_serial;
  UPDATE serial_unit SET status = 'SOLD', current_owner_id = v_owner WHERE serial_id = v_new_serial;
  -- 4. void old coverage, 5. carry remaining coverage to the new unit
  UPDATE warranty SET status = 'VOID' WHERE serial_id = v_old_serial AND status = 'ACTIVE';
  INSERT INTO warranty (serial_id, plan_id, start_date, end_date)
  VALUES (v_new_serial, v_plan, CURRENT_DATE, GREATEST(v_end, CURRENT_DATE + INTERVAL 1 DAY));
  -- 6. settle the claim, 7. complete the request
  UPDATE warranty_claim
  SET status = 'SETTLED', approved_amount = COALESCE(approved_amount, 0)
  WHERE claim_id = p_claim_id;
  UPDATE service_request SET status = 'COMPLETED'
  WHERE request_id = v_request AND status IN ('OPEN','ASSIGNED','IN_PROGRESS');
  -- 8. close any recall notice for the old unit
  UPDATE recall_notification SET status = 'RESOLVED' WHERE serial_id = v_old_serial;

  COMMIT;
END$$

DELIMITER ;

-- VIEWS
-- live queue for service staff
CREATE OR REPLACE VIEW v_open_service_queue AS
SELECT sr.request_id,
       sc.center_code,
       sr.priority,
       sr.status,
       sr.issue_type,
       c.full_name    AS customer_name,
       s.serial_no,
       pm.model_name,
       t.full_name    AS technician_name,
       fn_has_active_warranty(sr.serial_id, DATE(sr.request_date)) AS under_warranty,
       TIMESTAMPDIFF(HOUR, sr.request_date, NOW()) AS age_hours
FROM service_request sr
JOIN service_center sc ON sc.center_id = sr.center_id
JOIN customer c        ON c.customer_id = sr.customer_id
JOIN serial_unit s     ON s.serial_id = sr.serial_id
JOIN product_model pm  ON pm.model_id = s.model_id
LEFT JOIN repair r     ON r.request_id = sr.request_id
                      AND r.status IN ('ASSIGNED','IN_PROGRESS')
LEFT JOIN technician t ON t.technician_id = r.technician_id
WHERE sr.status IN ('OPEN','ASSIGNED','IN_PROGRESS');

-- technician scorecard
CREATE OR REPLACE VIEW v_technician_performance AS
SELECT t.technician_id,
       t.full_name,
       sc.center_code,
       t.skill_level,
       COUNT(r.repair_id)                                   AS total_jobs,
       COALESCE(SUM(r.status = 'COMPLETED'), 0)             AS completed_jobs,
       COALESCE(SUM(r.status IN ('ASSIGNED','IN_PROGRESS')), 0) AS open_jobs,
       ROUND(AVG(CASE WHEN r.status = 'COMPLETED'
                      THEN TIMESTAMPDIFF(HOUR, r.assigned_at, r.completed_at) END), 1)
                                                            AS avg_turnaround_hrs,
       COALESCE(SUM(r.labour_charge), 0)                    AS labour_billed
FROM technician t
JOIN service_center sc ON sc.center_id = t.center_id
LEFT JOIN repair r     ON r.technician_id = t.technician_id
GROUP BY t.technician_id, t.full_name, sc.center_code, t.skill_level;

-- parts that need restocking
CREATE OR REPLACE VIEW v_part_reorder_alert AS
SELECT part_code, part_name, part_category, stock_qty, reorder_level,
       (reorder_level * 2 - stock_qty) AS suggested_order_qty
FROM spare_part
WHERE stock_qty <= reorder_level;
