-- =====================================================================
-- sales_module/procedures_triggers.sql
-- Sales, Warranty and Recall module
-- Advanced features: stored functions, stored procedures with
-- transactions, triggers, views, scheduled event
-- =====================================================================
USE warranty_engine;

DROP FUNCTION  IF EXISTS fn_has_active_warranty;
DROP FUNCTION  IF EXISTS fn_unit_under_recall;
DROP PROCEDURE IF EXISTS sp_register_sale;
DROP PROCEDURE IF EXISTS sp_generate_recall_notifications;
DROP PROCEDURE IF EXISTS sp_expire_warranties;
DROP TRIGGER   IF EXISTS trg_purchase_item_bi;
DROP TRIGGER   IF EXISTS trg_purchase_item_ai;
DROP TRIGGER   IF EXISTS trg_purchase_item_ad;
DROP TRIGGER   IF EXISTS trg_warranty_bi;
DROP EVENT     IF EXISTS ev_daily_warranty_expiry;

DELIMITER $$

-- ---------------------------------------------------------------------
-- FUNCTION: is this unit covered by any non-void warranty on a date?
-- Also used by the service module's views and procedures.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_has_active_warranty(p_serial_id INT, p_on DATE)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM warranty
    WHERE serial_id = p_serial_id
      AND status <> 'VOID'
      AND p_on BETWEEN start_date AND end_date);
END$$

-- ---------------------------------------------------------------------
-- FUNCTION: returns the recall_id of an ACTIVE recall covering this unit,
-- or NULL if none.
-- ---------------------------------------------------------------------
CREATE FUNCTION fn_unit_under_recall(p_serial_id INT)
RETURNS INT
READS SQL DATA
BEGIN
  DECLARE v_recall INT DEFAULT NULL;
  SELECT rc.recall_id INTO v_recall
  FROM serial_unit s
  JOIN recall_scope rs    ON rs.model_id = s.model_id
                         AND s.manufacture_date BETWEEN rs.mfg_from AND rs.mfg_to
  JOIN recall_campaign rc ON rc.recall_id = rs.recall_id AND rc.status = 'ACTIVE'
  WHERE s.serial_id = p_serial_id
  ORDER BY rc.announced_on DESC
  LIMIT 1;
  RETURN v_recall;
END$$

-- ---------------------------------------------------------------------
-- TRIGGERS on purchase_item: validate sale, then mark unit as sold and
-- keep the invoice total in sync.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_purchase_item_bi
BEFORE INSERT ON purchase_item
FOR EACH ROW
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_mfg DATE;
  DECLARE v_purchase_date DATE;

  SELECT status, manufacture_date INTO v_status, v_mfg
  FROM serial_unit WHERE serial_id = NEW.serial_id FOR UPDATE;

  SELECT purchase_date INTO v_purchase_date
  FROM purchase WHERE purchase_id = NEW.purchase_id;

  IF v_status <> 'IN_STOCK' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unit is not in stock and cannot be sold';
  END IF;
  IF v_purchase_date < v_mfg THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Purchase date is before the unit manufacture date';
  END IF;
  IF fn_unit_under_recall(NEW.serial_id) IS NOT NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unit is under an active recall and cannot be sold';
  END IF;
END$$

CREATE TRIGGER trg_purchase_item_ai
AFTER INSERT ON purchase_item
FOR EACH ROW
BEGIN
  UPDATE serial_unit s
  JOIN purchase p ON p.purchase_id = NEW.purchase_id
  SET s.status = 'SOLD', s.current_owner_id = p.customer_id
  WHERE s.serial_id = NEW.serial_id;

  UPDATE purchase
  SET total_amount = total_amount + NEW.unit_price
  WHERE purchase_id = NEW.purchase_id;
END$$

-- sales return: warranty voided, unit back to stock, invoice total reduced
CREATE TRIGGER trg_purchase_item_ad
AFTER DELETE ON purchase_item
FOR EACH ROW
BEGIN
  UPDATE warranty SET status = 'VOID'
  WHERE serial_id = OLD.serial_id AND status = 'ACTIVE';

  UPDATE serial_unit
  SET status = 'IN_STOCK', current_owner_id = NULL
  WHERE serial_id = OLD.serial_id AND status = 'SOLD';

  UPDATE purchase
  SET total_amount = GREATEST(total_amount - OLD.unit_price, 0)
  WHERE purchase_id = OLD.purchase_id;
END$$

-- ---------------------------------------------------------------------
-- TRIGGER on warranty: compute end_date from the plan, allow warranties
-- only on owned units, and block overlapping warranties of the same type.
-- ---------------------------------------------------------------------
CREATE TRIGGER trg_warranty_bi
BEFORE INSERT ON warranty
FOR EACH ROW
BEGIN
  DECLARE v_months INT;
  DECLARE v_type VARCHAR(20);
  DECLARE v_unit_status VARCHAR(20);

  SELECT duration_months, plan_type INTO v_months, v_type
  FROM warranty_plan WHERE plan_id = NEW.plan_id;

  IF NEW.end_date IS NULL THEN
    SET NEW.end_date = DATE_ADD(NEW.start_date, INTERVAL v_months MONTH);
  END IF;

  SELECT status INTO v_unit_status FROM serial_unit WHERE serial_id = NEW.serial_id;
  IF v_unit_status <> 'SOLD' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Warranty can only be issued for a sold unit';
  END IF;

  IF EXISTS (
      SELECT 1 FROM warranty w
      JOIN warranty_plan wp ON wp.plan_id = w.plan_id
      WHERE w.serial_id = NEW.serial_id
        AND w.status = 'ACTIVE'
        AND wp.plan_type = v_type
        AND NEW.start_date <= w.end_date
        AND NEW.end_date   >= w.start_date) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Overlapping active warranty of the same type exists';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE (TRANSACTION): register a one-unit sale with its warranty.
-- Purchase, purchase item and warranty are created together or not at all.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_register_sale(
  IN  p_customer_id   INT,
  IN  p_invoice_no    VARCHAR(20),
  IN  p_purchase_date DATE,
  IN  p_channel       VARCHAR(20),
  IN  p_serial_no     VARCHAR(30),
  IN  p_price         DECIMAL(10,2),
  IN  p_plan_code     VARCHAR(20),
  OUT p_purchase_id   INT)
BEGIN
  DECLARE v_serial_id INT DEFAULT NULL;
  DECLARE v_plan_id   INT DEFAULT NULL;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT serial_id INTO v_serial_id
  FROM serial_unit WHERE serial_no = p_serial_no FOR UPDATE;
  IF v_serial_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown serial number';
  END IF;

  SELECT plan_id INTO v_plan_id FROM warranty_plan WHERE plan_code = p_plan_code;
  IF v_plan_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Unknown warranty plan code';
  END IF;

  INSERT INTO purchase (invoice_no, customer_id, purchase_date, channel)
  VALUES (p_invoice_no, p_customer_id, p_purchase_date, p_channel);
  SET p_purchase_id = LAST_INSERT_ID();

  INSERT INTO purchase_item (purchase_id, serial_id, unit_price)
  VALUES (p_purchase_id, v_serial_id, p_price);

  INSERT INTO warranty (serial_id, plan_id, start_date, end_date)
  VALUES (v_serial_id, v_plan_id, p_purchase_date, NULL);

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE (TRANSACTION): find every sold unit inside a recall's scope
-- and queue one notification per unit to its current owner.
-- Safe to run repeatedly: already-notified units are skipped.
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_generate_recall_notifications(
  IN  p_recall_id INT,
  OUT p_created   INT)
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  IF NOT EXISTS (SELECT 1 FROM recall_campaign
                 WHERE recall_id = p_recall_id AND status <> 'CLOSED') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Recall does not exist or is already closed';
  END IF;

  START TRANSACTION;

  INSERT INTO recall_notification (recall_id, serial_id, customer_id, channel)
  SELECT rs.recall_id, s.serial_id, c.customer_id, c.preferred_channel
  FROM recall_scope rs
  JOIN serial_unit s ON s.model_id = rs.model_id
                    AND s.manufacture_date BETWEEN rs.mfg_from AND rs.mfg_to
  JOIN customer c    ON c.customer_id = s.current_owner_id
  WHERE rs.recall_id = p_recall_id
    AND s.status = 'SOLD'
    AND NOT EXISTS (SELECT 1 FROM recall_notification n
                    WHERE n.recall_id = rs.recall_id AND n.serial_id = s.serial_id);
  SET p_created = ROW_COUNT();

  UPDATE recall_campaign SET status = 'ACTIVE'
  WHERE recall_id = p_recall_id AND status = 'ANNOUNCED';

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- PROCEDURE: mark warranties past their end date as EXPIRED
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_expire_warranties()
BEGIN
  UPDATE warranty
  SET status = 'EXPIRED'
  WHERE status = 'ACTIVE' AND end_date < CURRENT_DATE;
END$$

-- ---------------------------------------------------------------------
-- EVENT: run the expiry job daily (needs event_scheduler=ON)
-- ---------------------------------------------------------------------
CREATE EVENT ev_daily_warranty_expiry
ON SCHEDULE EVERY 1 DAY STARTS (CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR)
DO CALL sp_expire_warranties()$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- VIEW: one row per warranty with live status and days remaining
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_warranty_overview AS
SELECT w.warranty_id,
       c.customer_id,
       c.full_name            AS customer_name,
       s.serial_no,
       p.brand,
       pm.model_name,
       wp.plan_code,
       wp.plan_type,
       w.start_date,
       w.end_date,
       CASE
         WHEN w.status = 'VOID'                          THEN 'VOID'
         WHEN w.end_date < CURRENT_DATE                  THEN 'EXPIRED'
         WHEN w.end_date <= CURRENT_DATE + INTERVAL 30 DAY THEN 'EXPIRING_SOON'
         ELSE 'ACTIVE'
       END                    AS live_status,
       CASE WHEN w.status = 'VOID' THEN 0
            ELSE GREATEST(DATEDIFF(w.end_date, CURRENT_DATE), 0) END AS days_left
FROM warranty w
JOIN serial_unit s     ON s.serial_id   = w.serial_id
JOIN product_model pm  ON pm.model_id   = s.model_id
JOIN product p         ON p.product_id  = pm.product_id
JOIN warranty_plan wp  ON wp.plan_id    = w.plan_id
LEFT JOIN customer c   ON c.customer_id = s.current_owner_id;

-- ---------------------------------------------------------------------
-- VIEW: every unit affected by a recall, with owner and notification state
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_recall_affected_units AS
SELECT rc.recall_code,
       rc.title,
       rc.severity,
       rc.status              AS recall_status,
       pm.model_name,
       s.serial_no,
       s.manufacture_date,
       s.status               AS unit_status,
       c.full_name            AS owner_name,
       c.email                AS owner_email,
       COALESCE(n.status, 'NOT_NOTIFIED') AS notification_status
FROM recall_campaign rc
JOIN recall_scope rs  ON rs.recall_id = rc.recall_id
JOIN serial_unit s    ON s.model_id = rs.model_id
                     AND s.manufacture_date BETWEEN rs.mfg_from AND rs.mfg_to
JOIN product_model pm ON pm.model_id = s.model_id
LEFT JOIN customer c  ON c.customer_id = s.current_owner_id
LEFT JOIN recall_notification n
       ON n.recall_id = rc.recall_id AND n.serial_id = s.serial_id;
