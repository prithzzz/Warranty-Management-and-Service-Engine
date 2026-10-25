-- =====================================================================
-- sales_module/tables.sql
-- Sales, Warranty and Recall module
-- Tables: customer, product, product_model, serial_unit, purchase,
--         purchase_item, warranty_plan, warranty, recall_campaign,
--         recall_scope, recall_notification
-- Shows: CREATE, DROP, ALTER, PK, FK, UNIQUE, CHECK, DEFAULT, indexes
-- =====================================================================
USE warranty_engine;

-- DROP: makes this file safely re-runnable (child tables first)
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS recall_notification, recall_scope, recall_campaign,
                     warranty, warranty_plan, purchase_item, purchase,
                     serial_unit, product_model, product, customer;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- CUSTOMER
-- ---------------------------------------------------------------------
CREATE TABLE customer (
  customer_id    INT AUTO_INCREMENT PRIMARY KEY,
  full_name      VARCHAR(100) NOT NULL,
  email          VARCHAR(120) NOT NULL,
  phone          CHAR(10)     NOT NULL,
  address        VARCHAR(255),
  city           VARCHAR(60)  NOT NULL,
  registered_on  DATE         NOT NULL DEFAULT (CURRENT_DATE),
  CONSTRAINT uq_customer_email UNIQUE (email),
  CONSTRAINT uq_customer_phone UNIQUE (phone),
  CONSTRAINT chk_customer_email CHECK (email REGEXP '^[^@ ]+@[^@ ]+[.][a-z]{2,}$'),
  CONSTRAINT chk_customer_phone CHECK (phone REGEXP '^[6-9][0-9]{9}$'),
  CONSTRAINT chk_customer_name  CHECK (CHAR_LENGTH(TRIM(full_name)) >= 2)
);

-- ---------------------------------------------------------------------
-- PRODUCT and PRODUCT_MODEL  (a product line has many models)
-- ---------------------------------------------------------------------
CREATE TABLE product (
  product_id    INT AUTO_INCREMENT PRIMARY KEY,
  product_name  VARCHAR(100) NOT NULL,
  brand         VARCHAR(60)  NOT NULL,
  category      ENUM('SMARTPHONE','LAPTOP','TABLET','TELEVISION',
                     'APPLIANCE','WEARABLE','AUDIO') NOT NULL,
  CONSTRAINT uq_product_brand_name UNIQUE (brand, product_name)
);

CREATE TABLE product_model (
  model_id     INT AUTO_INCREMENT PRIMARY KEY,
  product_id   INT          NOT NULL,
  model_code   VARCHAR(30)  NOT NULL,
  model_name   VARCHAR(100) NOT NULL,
  launch_date  DATE         NOT NULL,
  mrp          DECIMAL(10,2) NOT NULL,
  CONSTRAINT uq_model_code UNIQUE (model_code),
  CONSTRAINT chk_model_mrp CHECK (mrp > 0),
  CONSTRAINT fk_model_product FOREIGN KEY (product_id)
    REFERENCES product(product_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- SERIAL_UNIT  (one physical unit; the thing a warranty actually covers)
-- current_owner_id is maintained by triggers on sale and replacement.
-- ---------------------------------------------------------------------
CREATE TABLE serial_unit (
  serial_id         INT AUTO_INCREMENT PRIMARY KEY,
  serial_no         VARCHAR(30) NOT NULL,
  model_id          INT         NOT NULL,
  manufacture_date  DATE        NOT NULL,
  status            ENUM('IN_STOCK','SOLD','REPLACED','SCRAPPED')
                    NOT NULL DEFAULT 'IN_STOCK',
  current_owner_id  INT NULL,
  CONSTRAINT uq_serial_no UNIQUE (serial_no),
  CONSTRAINT fk_serial_model FOREIGN KEY (model_id)
    REFERENCES product_model(model_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_serial_owner FOREIGN KEY (current_owner_id)
    REFERENCES customer(customer_id),
  -- an in-stock unit has no owner, a sold unit must have one
  CONSTRAINT chk_serial_owner CHECK (
    NOT (status = 'IN_STOCK' AND current_owner_id IS NOT NULL)
    AND NOT (status = 'SOLD' AND current_owner_id IS NULL))
);

-- ---------------------------------------------------------------------
-- PURCHASE and PURCHASE_ITEM  (one invoice, many serial units)
-- ---------------------------------------------------------------------
CREATE TABLE purchase (
  purchase_id    INT AUTO_INCREMENT PRIMARY KEY,
  invoice_no     VARCHAR(20) NOT NULL,
  customer_id    INT         NOT NULL,
  purchase_date  DATE        NOT NULL,
  channel        ENUM('ONLINE','RETAIL_STORE','DEALER') NOT NULL,
  total_amount   DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT uq_invoice_no UNIQUE (invoice_no),
  CONSTRAINT chk_purchase_total CHECK (total_amount >= 0),
  CONSTRAINT fk_purchase_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id) ON DELETE RESTRICT
);

CREATE TABLE purchase_item (
  purchase_item_id  INT AUTO_INCREMENT PRIMARY KEY,
  purchase_id       INT NOT NULL,
  serial_id         INT NOT NULL,
  unit_price        DECIMAL(10,2) NOT NULL,
  CONSTRAINT uq_item_serial UNIQUE (serial_id),      -- a unit is sold once
  CONSTRAINT chk_item_price CHECK (unit_price > 0),
  CONSTRAINT fk_item_purchase FOREIGN KEY (purchase_id)
    REFERENCES purchase(purchase_id) ON DELETE CASCADE,
  CONSTRAINT fk_item_serial FOREIGN KEY (serial_id)
    REFERENCES serial_unit(serial_id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- WARRANTY_PLAN and WARRANTY
-- end_date may be passed as NULL; trigger trg_warranty_bi computes it.
-- ---------------------------------------------------------------------
CREATE TABLE warranty_plan (
  plan_id          INT AUTO_INCREMENT PRIMARY KEY,
  plan_code        VARCHAR(20) NOT NULL,
  plan_name        VARCHAR(80) NOT NULL,
  plan_type        ENUM('STANDARD','EXTENDED','ACCIDENTAL_DAMAGE') NOT NULL,
  duration_months  TINYINT UNSIGNED NOT NULL,
  max_claims       TINYINT UNSIGNED NOT NULL DEFAULT 3,
  coverage_desc    VARCHAR(255) NOT NULL,
  price            DECIMAL(10,2) NOT NULL DEFAULT 0,
  CONSTRAINT uq_plan_code UNIQUE (plan_code),
  CONSTRAINT chk_plan_duration CHECK (duration_months BETWEEN 1 AND 60),
  CONSTRAINT chk_plan_claims   CHECK (max_claims >= 1),
  CONSTRAINT chk_plan_price    CHECK (price >= 0)
);

CREATE TABLE warranty (
  warranty_id  INT AUTO_INCREMENT PRIMARY KEY,
  serial_id    INT  NOT NULL,
  plan_id      INT  NOT NULL,
  start_date   DATE NOT NULL,
  end_date     DATE NOT NULL,
  status       ENUM('ACTIVE','EXPIRED','VOID') NOT NULL DEFAULT 'ACTIVE',
  CONSTRAINT chk_warranty_dates CHECK (end_date > start_date),
  CONSTRAINT fk_warranty_serial FOREIGN KEY (serial_id)
    REFERENCES serial_unit(serial_id) ON DELETE RESTRICT,
  CONSTRAINT fk_warranty_plan FOREIGN KEY (plan_id)
    REFERENCES warranty_plan(plan_id) ON DELETE RESTRICT
);

-- ---------------------------------------------------------------------
-- RECALL_CAMPAIGN, RECALL_SCOPE, RECALL_NOTIFICATION
-- A scope says "model X manufactured between date1 and date2 is affected".
-- ---------------------------------------------------------------------
CREATE TABLE recall_campaign (
  recall_id     INT AUTO_INCREMENT PRIMARY KEY,
  recall_code   VARCHAR(20)  NOT NULL,
  title         VARCHAR(150) NOT NULL,
  reason        TEXT         NOT NULL,
  severity      ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
  remedy        ENUM('INSPECT','REPAIR','REPLACE','REFUND') NOT NULL,
  announced_on  DATE NOT NULL,
  status        ENUM('ANNOUNCED','ACTIVE','CLOSED') NOT NULL DEFAULT 'ANNOUNCED',
  CONSTRAINT uq_recall_code UNIQUE (recall_code)
);

CREATE TABLE recall_scope (
  scope_id   INT AUTO_INCREMENT PRIMARY KEY,
  recall_id  INT  NOT NULL,
  model_id   INT  NOT NULL,
  mfg_from   DATE NOT NULL,
  mfg_to     DATE NOT NULL,
  CONSTRAINT uq_scope UNIQUE (recall_id, model_id, mfg_from),
  CONSTRAINT chk_scope_range CHECK (mfg_to >= mfg_from),
  CONSTRAINT fk_scope_recall FOREIGN KEY (recall_id)
    REFERENCES recall_campaign(recall_id) ON DELETE CASCADE,
  CONSTRAINT fk_scope_model FOREIGN KEY (model_id)
    REFERENCES product_model(model_id) ON DELETE RESTRICT
);

CREATE TABLE recall_notification (
  notification_id  INT AUTO_INCREMENT PRIMARY KEY,
  recall_id        INT NOT NULL,
  serial_id        INT NOT NULL,
  customer_id      INT NOT NULL,
  channel          ENUM('EMAIL','SMS','APP') NOT NULL DEFAULT 'EMAIL',
  notified_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status           ENUM('PENDING','SENT','ACKNOWLEDGED','RESOLVED')
                   NOT NULL DEFAULT 'PENDING',
  CONSTRAINT uq_notify_once UNIQUE (recall_id, serial_id),
  CONSTRAINT fk_notify_recall FOREIGN KEY (recall_id)
    REFERENCES recall_campaign(recall_id) ON DELETE CASCADE,
  CONSTRAINT fk_notify_serial FOREIGN KEY (serial_id)
    REFERENCES serial_unit(serial_id),
  CONSTRAINT fk_notify_customer FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id)
);

-- ---------------------------------------------------------------------
-- ALTER: schema evolution after the initial design
-- ---------------------------------------------------------------------
-- customers can choose how they want recall alerts delivered
ALTER TABLE customer
  ADD COLUMN preferred_channel ENUM('EMAIL','SMS','APP') NOT NULL DEFAULT 'EMAIL'
  AFTER city;

-- full-text search over recall announcements
ALTER TABLE recall_campaign ADD FULLTEXT INDEX ft_recall_text (title, reason);

-- ---------------------------------------------------------------------
-- INDEXES for the most frequent lookups
-- ---------------------------------------------------------------------
-- customer purchase history, newest first
CREATE INDEX idx_purchase_customer_date ON purchase (customer_id, purchase_date);
-- recall matching: "units of model X made between d1 and d2"
CREATE INDEX idx_serial_model_mfg ON serial_unit (model_id, manufacture_date);
-- warranty validity check for a unit on a date
CREATE INDEX idx_warranty_serial_dates ON warranty (serial_id, start_date, end_date);
-- nightly expiry job scans active warranties by end date
CREATE INDEX idx_warranty_status_end ON warranty (status, end_date);
