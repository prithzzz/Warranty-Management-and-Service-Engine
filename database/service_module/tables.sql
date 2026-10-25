USE warranty_engine;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS app_user, service_status_log, replacement,
                     warranty_claim, repair_part, repair, service_request,
                     spare_part, technician, service_center;
SET FOREIGN_KEY_CHECKS = 1;

-- SERVICE_CENTER and TECHNICIAN
CREATE TABLE service_center (
  center_id    INT AUTO_INCREMENT PRIMARY KEY,
  center_code  VARCHAR(10)  NOT NULL,
  center_name  VARCHAR(100) NOT NULL,
  city         VARCHAR(60)  NOT NULL,
  address      VARCHAR(255) NOT NULL,
  phone        CHAR(10)     NOT NULL,
  email        VARCHAR(120) NOT NULL,
  CONSTRAINT uq_center_code  UNIQUE (center_code),
  CONSTRAINT uq_center_email UNIQUE (email),
  CONSTRAINT chk_center_phone CHECK (phone REGEXP '^[0-9]{10}$'),
  CONSTRAINT chk_center_email CHECK (email REGEXP '^[^@ ]+@[^@ ]+[.][a-z]{2,}$')
);

CREATE TABLE technician (
  technician_id   INT AUTO_INCREMENT PRIMARY KEY,
  center_id       INT          NOT NULL,
  full_name       VARCHAR(100) NOT NULL,
  phone           CHAR(10)     NOT NULL,
  email           VARCHAR(120) NOT NULL,
  skill_level     ENUM('JUNIOR','SENIOR','EXPERT') NOT NULL,
  specialization  ENUM('SMARTPHONE','LAPTOP','TABLET','TELEVISION',
                       'APPLIANCE','WEARABLE','AUDIO') NOT NULL,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT uq_tech_phone UNIQUE (phone),
  CONSTRAINT uq_tech_email UNIQUE (email),
  CONSTRAINT chk_tech_phone CHECK (phone REGEXP '^[6-9][0-9]{9}$'),
  CONSTRAINT fk_tech_center FOREIGN KEY (center_id)
    REFERENCES service_center(center_id) ON DELETE RESTRICT
);

-- SPARE_PART  (inventory; stock is changed only through repair_part triggers)
CREATE TABLE spare_part (
  part_id        INT AUTO_INCREMENT PRIMARY KEY,
  part_code      VARCHAR(20)  NOT NULL,
  part_name      VARCHAR(100) NOT NULL,
  part_category  ENUM('DISPLAY','BATTERY','BOARD','CAMERA','CHARGING',
                      'BODY','AUDIO','COMPRESSOR','OTHER') NOT NULL,
  unit_price     DECIMAL(10,2) NOT NULL,
  stock_qty      INT NOT NULL DEFAULT 0,
  reorder_level  INT NOT NULL DEFAULT 5,
  CONSTRAINT uq_part_code UNIQUE (part_code),
  CONSTRAINT chk_part_price   CHECK (unit_price > 0),
  CONSTRAINT chk_part_stock   CHECK (stock_qty >= 0),
  CONSTRAINT chk_part_reorder CHECK (reorder_level >= 0)
);

-- SERVICE_REQUEST  (a customer reports a problem with one unit)
CREATE TABLE service_request (
  request_id         INT AUTO_INCREMENT PRIMARY KEY,
  customer_id        INT NOT NULL,
  serial_id          INT NOT NULL,
  center_id          INT NOT NULL,
  request_date       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  issue_type         ENUM('HARDWARE','SOFTWARE','PHYSICAL_DAMAGE','BATTERY',
                          'DISPLAY','RECALL_FIX','OTHER') NOT NULL,
  issue_description  TEXT NOT NULL,
  priority           ENUM('LOW','MEDIUM','HIGH','URGENT') NOT NULL DEFAULT 'MEDIUM',
  status             ENUM('OPEN','ASSIGNED','IN_PROGRESS','COMPLETED',
                          'CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  closed_at          DATETIME NULL,
  CONSTRAINT chk_sr_description CHECK (CHAR_LENGTH(issue_description) >= 10),
  CONSTRAINT chk_sr_closed CHECK (closed_at IS NULL OR closed_at >= request_date),
  CONSTRAINT fk_sr_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id) ON DELETE RESTRICT,
  CONSTRAINT fk_sr_serial FOREIGN KEY (serial_id)
    REFERENCES serial_unit(serial_id) ON DELETE RESTRICT,
  CONSTRAINT fk_sr_center FOREIGN KEY (center_id)
    REFERENCES service_center(center_id) ON DELETE RESTRICT
);

-- REPAIR and REPAIR_PART  (M:N between repair and spare_part)
CREATE TABLE repair (
  repair_id         INT AUTO_INCREMENT PRIMARY KEY,
  request_id        INT NOT NULL,
  technician_id     INT NOT NULL,
  assigned_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at      DATETIME NULL,
  labour_charge     DECIMAL(10,2) NOT NULL DEFAULT 0,
  status            ENUM('ASSIGNED','IN_PROGRESS','COMPLETED','FAILED')
                    NOT NULL DEFAULT 'ASSIGNED',
  resolution_notes  VARCHAR(500),
  CONSTRAINT chk_repair_labour CHECK (labour_charge >= 0),
  CONSTRAINT chk_repair_dates  CHECK (completed_at IS NULL OR completed_at >= assigned_at),
  CONSTRAINT chk_repair_done   CHECK (status <> 'COMPLETED' OR completed_at IS NOT NULL),
  CONSTRAINT fk_repair_request FOREIGN KEY (request_id)
    REFERENCES service_request(request_id) ON DELETE RESTRICT,
  CONSTRAINT fk_repair_tech FOREIGN KEY (technician_id)
    REFERENCES technician(technician_id) ON DELETE RESTRICT
);

CREATE TABLE repair_part (
  repair_id   INT NOT NULL,
  part_id     INT NOT NULL,
  quantity    SMALLINT NOT NULL,
  unit_price  DECIMAL(10,2) NOT NULL,   -- price frozen at time of use
  PRIMARY KEY (repair_id, part_id),
  CONSTRAINT chk_rp_qty   CHECK (quantity > 0),
  CONSTRAINT chk_rp_price CHECK (unit_price > 0),
  CONSTRAINT fk_rp_repair FOREIGN KEY (repair_id)
    REFERENCES repair(repair_id) ON DELETE CASCADE,
  CONSTRAINT fk_rp_part FOREIGN KEY (part_id)
    REFERENCES spare_part(part_id) ON DELETE RESTRICT
);

-- WARRANTY_CLAIM and REPLACEMENT
CREATE TABLE warranty_claim (
  claim_id         INT AUTO_INCREMENT PRIMARY KEY,
  warranty_id      INT  NOT NULL,
  request_id       INT  NOT NULL,
  claim_date       DATE NOT NULL,
  claim_type       ENUM('REPAIR','REPLACEMENT','REFUND') NOT NULL,
  status           ENUM('SUBMITTED','APPROVED','REJECTED','SETTLED')
                   NOT NULL DEFAULT 'SUBMITTED',
  approved_amount  DECIMAL(10,2) NULL,
  remarks          VARCHAR(255),
  CONSTRAINT uq_claim_request UNIQUE (request_id),    -- one claim per request
  CONSTRAINT chk_claim_amount  CHECK (approved_amount IS NULL OR approved_amount >= 0),
  CONSTRAINT chk_claim_settled CHECK (status <> 'SETTLED' OR approved_amount IS NOT NULL),
  CONSTRAINT fk_claim_warranty FOREIGN KEY (warranty_id)
    REFERENCES warranty(warranty_id) ON DELETE RESTRICT,
  CONSTRAINT fk_claim_request FOREIGN KEY (request_id)
    REFERENCES service_request(request_id) ON DELETE RESTRICT
);

CREATE TABLE replacement (
  replacement_id  INT AUTO_INCREMENT PRIMARY KEY,
  claim_id        INT  NOT NULL,
  old_serial_id   INT  NOT NULL,
  new_serial_id   INT  NOT NULL,
  replaced_on     DATE NOT NULL,
  notes           VARCHAR(255),
  CONSTRAINT uq_repl_claim UNIQUE (claim_id),
  CONSTRAINT uq_repl_new   UNIQUE (new_serial_id),
  CONSTRAINT chk_repl_diff CHECK (old_serial_id <> new_serial_id),
  CONSTRAINT fk_repl_claim FOREIGN KEY (claim_id)
    REFERENCES warranty_claim(claim_id) ON DELETE RESTRICT,
  CONSTRAINT fk_repl_old FOREIGN KEY (old_serial_id)
    REFERENCES serial_unit(serial_id),
  CONSTRAINT fk_repl_new FOREIGN KEY (new_serial_id)
    REFERENCES serial_unit(serial_id)
);

-- SERVICE_STATUS_LOG  (audit trail, filled only by triggers)
CREATE TABLE service_status_log (
  log_id      INT AUTO_INCREMENT PRIMARY KEY,
  request_id  INT NOT NULL,
  old_status  VARCHAR(20) NULL,
  new_status  VARCHAR(20) NOT NULL,
  changed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  changed_by  VARCHAR(100) NOT NULL DEFAULT (CURRENT_USER()),
  CONSTRAINT fk_log_request FOREIGN KEY (request_id)
    REFERENCES service_request(request_id) ON DELETE CASCADE
);

-- APP_USER  (login accounts for the future Next.js app, 4 roles)
-- A CUSTOMER login must link to a customer row, a TECHNICIAN login to a technician row, and SERVICE_STAFF to the center they work at.
CREATE TABLE app_user (
  user_id        INT AUTO_INCREMENT PRIMARY KEY,
  username       VARCHAR(40)  NOT NULL,
  email          VARCHAR(120) NOT NULL,
  password_hash  CHAR(60)     NOT NULL,          -- bcrypt hash, never plain text
  role           ENUM('ADMIN','SERVICE_STAFF','TECHNICIAN','CUSTOMER') NOT NULL,
  customer_id    INT NULL,
  technician_id  INT NULL,
  center_id      INT NULL,
  is_active      BOOLEAN  NOT NULL DEFAULT TRUE,
  created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_user_username UNIQUE (username),
  CONSTRAINT uq_user_email    UNIQUE (email),
  CONSTRAINT uq_user_customer UNIQUE (customer_id),
  CONSTRAINT uq_user_tech     UNIQUE (technician_id),
  CONSTRAINT chk_user_hash CHECK (password_hash LIKE '$2_$%'),
  CONSTRAINT chk_user_customer_link CHECK ((role = 'CUSTOMER') = (customer_id IS NOT NULL)),
  CONSTRAINT chk_user_tech_link     CHECK ((role = 'TECHNICIAN') = (technician_id IS NOT NULL)),
  CONSTRAINT chk_user_staff_link    CHECK ((role = 'SERVICE_STAFF') = (center_id IS NOT NULL)),
  CONSTRAINT fk_user_customer FOREIGN KEY (customer_id) REFERENCES customer(customer_id),
  CONSTRAINT fk_user_tech     FOREIGN KEY (technician_id) REFERENCES technician(technician_id),
  CONSTRAINT fk_user_center   FOREIGN KEY (center_id) REFERENCES service_center(center_id)
);

-- ALTER: link service requests to recall campaigns (recall repairs are tracked separately from normal faults)
ALTER TABLE service_request
  ADD COLUMN recall_id INT NULL AFTER issue_type,
  ADD CONSTRAINT fk_sr_recall FOREIGN KEY (recall_id)
      REFERENCES recall_campaign(recall_id) ON DELETE RESTRICT,
  ADD CONSTRAINT chk_sr_recall CHECK ((issue_type = 'RECALL_FIX') = (recall_id IS NOT NULL));
-- full-text search over problem descriptions
ALTER TABLE service_request ADD FULLTEXT INDEX ft_sr_issue (issue_description);

-- INDEXES
CREATE INDEX idx_sr_status_priority ON service_request (status, priority, request_date);
CREATE INDEX idx_sr_center_status   ON service_request (center_id, status);
CREATE INDEX idx_repair_tech_status ON repair (technician_id, status);
CREATE INDEX idx_claim_warranty_status ON warranty_claim (warranty_id, status);
