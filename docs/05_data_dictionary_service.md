# 5. Data Dictionary: Service, Repair and Claims Module

Generated from the live MySQL schema (information_schema). PK means primary key; INDEX means an indexed column, usually a foreign key.

## service_center

Physical service locations.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| center_id | int | NO | PK, auto increment |  |  |
| center_code | varchar(10) | NO | UNIQUE |  |  |
| center_name | varchar(100) | NO |  |  |  |
| city | varchar(60) | NO |  |  |  |
| address | varchar(255) | NO |  |  |  |
| phone | char(10) | NO |  |  |  |
| email | varchar(120) | NO | UNIQUE |  |  |

Check constraints:

- chk_center_email: `regexp_like(email,'^[^@ ]+@[^@ ]+[.][a-z]{2,}$')`
- chk_center_phone: `regexp_like(phone,'^[0-9]{10}$')`

## technician

Technicians working at a service center.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| technician_id | int | NO | PK, auto increment |  |  |
| center_id | int | NO | INDEX |  | service_center.center_id |
| full_name | varchar(100) | NO |  |  |  |
| phone | char(10) | NO | UNIQUE |  |  |
| email | varchar(120) | NO | UNIQUE |  |  |
| skill_level | enum(JUNIOR, SENIOR, EXPERT) | NO |  |  |  |
| specialization | enum(SMARTPHONE, LAPTOP, TABLET, TELEVISION, APPLIANCE, WEARABLE, AUDIO) | NO |  |  |  |
| is_active | tinyint(1) | NO |  | 1 |  |

Check constraints:

- chk_tech_phone: `regexp_like(phone,'^[6-9][0-9]{9}$')`

## spare_part

Spare part inventory. Stock changes only through repair_part triggers or restocking.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| part_id | int | NO | PK, auto increment |  |  |
| part_code | varchar(20) | NO | UNIQUE |  |  |
| part_name | varchar(100) | NO |  |  |  |
| part_category | enum(DISPLAY, BATTERY, BOARD, CAMERA, CHARGING, BODY, AUDIO, COMPRESSOR, OTHER) | NO |  |  |  |
| unit_price | decimal(10,2) | NO |  |  |  |
| stock_qty | int | NO |  | 0 |  |
| reorder_level | int | NO |  | 5 |  |

Check constraints:

- chk_part_price: `(unit_price > 0)`
- chk_part_reorder: `(reorder_level >= 0)`
- chk_part_stock: `(stock_qty >= 0)`

## service_request

A customer complaint about one unit, handled by one service center.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| request_id | int | NO | PK, auto increment |  |  |
| customer_id | int | NO | INDEX |  | customer.customer_id |
| serial_id | int | NO | INDEX |  | serial_unit.serial_id |
| center_id | int | NO | INDEX |  | service_center.center_id |
| request_date | datetime | NO |  | CURRENT_TIMESTAMP |  |
| issue_type | enum(HARDWARE, SOFTWARE, PHYSICAL_DAMAGE, BATTERY, DISPLAY, RECALL_FIX, OTHER) | NO |  |  |  |
| recall_id | int | YES | INDEX |  | recall_campaign.recall_id |
| issue_description | text | NO | INDEX |  |  |
| priority | enum(LOW, MEDIUM, HIGH, URGENT) | NO |  | MEDIUM |  |
| status | enum(OPEN, ASSIGNED, IN_PROGRESS, COMPLETED, CLOSED, CANCELLED) | NO | INDEX | OPEN |  |
| closed_at | datetime | YES |  |  |  |

Check constraints:

- chk_sr_closed: `((closed_at is null) or (closed_at >= request_date))`
- chk_sr_description: `(char_length(issue_description) >= 10)`
- chk_sr_recall: `((issue_type = 'RECALL_FIX') = (recall_id is not null))`

## repair

Work done by a technician on a service request.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| repair_id | int | NO | PK, auto increment |  |  |
| request_id | int | NO | INDEX |  | service_request.request_id |
| technician_id | int | NO | INDEX |  | technician.technician_id |
| assigned_at | datetime | NO |  | CURRENT_TIMESTAMP |  |
| completed_at | datetime | YES |  |  |  |
| labour_charge | decimal(10,2) | NO |  | 0.00 |  |
| status | enum(ASSIGNED, IN_PROGRESS, COMPLETED, FAILED) | NO |  | ASSIGNED |  |
| resolution_notes | varchar(500) | YES |  |  |  |

Check constraints:

- chk_repair_dates: `((completed_at is null) or (completed_at >= assigned_at))`
- chk_repair_done: `((status <> 'COMPLETED') or (completed_at is not null))`
- chk_repair_labour: `(labour_charge >= 0)`

## repair_part

Parts used in a repair, with the price frozen at the time of use.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| repair_id | int | NO | PK |  | repair.repair_id |
| part_id | int | NO | PK |  | spare_part.part_id |
| quantity | smallint | NO |  |  |  |
| unit_price | decimal(10,2) | NO |  |  |  |

Check constraints:

- chk_rp_price: `(unit_price > 0)`
- chk_rp_qty: `(quantity > 0)`

## warranty_claim

A claim against a warranty for one service request.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| claim_id | int | NO | PK, auto increment |  |  |
| warranty_id | int | NO | INDEX |  | warranty.warranty_id |
| request_id | int | NO | UNIQUE |  | service_request.request_id |
| claim_date | date | NO |  |  |  |
| claim_type | enum(REPAIR, REPLACEMENT, REFUND) | NO |  |  |  |
| status | enum(SUBMITTED, APPROVED, REJECTED, SETTLED) | NO |  | SUBMITTED |  |
| approved_amount | decimal(10,2) | YES |  |  |  |
| remarks | varchar(255) | YES |  |  |  |

Check constraints:

- chk_claim_amount: `((approved_amount is null) or (approved_amount >= 0))`
- chk_claim_settled: `((status <> 'SETTLED') or (approved_amount is not null))`

## replacement

Record of a faulty unit swapped for a new one under a claim.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| replacement_id | int | NO | PK, auto increment |  |  |
| claim_id | int | NO | UNIQUE |  | warranty_claim.claim_id |
| old_serial_id | int | NO | INDEX |  | serial_unit.serial_id |
| new_serial_id | int | NO | UNIQUE |  | serial_unit.serial_id |
| replaced_on | date | NO |  |  |  |
| notes | varchar(255) | YES |  |  |  |

Check constraints:

- chk_repl_diff: `(old_serial_id <> new_serial_id)`

## service_status_log

Audit trail of every service request status change, written by triggers.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| log_id | int | NO | PK, auto increment |  |  |
| request_id | int | NO | INDEX |  | service_request.request_id |
| old_status | varchar(20) | YES |  |  |  |
| new_status | varchar(20) | NO |  |  |  |
| changed_at | datetime | NO |  | CURRENT_TIMESTAMP |  |
| changed_by | varchar(100) | NO |  | system |  |

## app_user

Login accounts for the web application, each with one of four roles.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| user_id | int | NO | PK, auto increment |  |  |
| username | varchar(40) | NO | UNIQUE |  |  |
| email | varchar(120) | NO | UNIQUE |  |  |
| password_hash | char(60) | NO |  |  |  |
| role | enum(ADMIN, SERVICE_STAFF, TECHNICIAN, CUSTOMER) | NO |  |  |  |
| customer_id | int | YES | UNIQUE |  | customer.customer_id |
| technician_id | int | YES | UNIQUE |  | technician.technician_id |
| center_id | int | YES | INDEX |  | service_center.center_id |
| is_active | tinyint(1) | NO |  | 1 |  |
| created_at | datetime | NO |  | CURRENT_TIMESTAMP |  |

Check constraints:

- chk_user_customer_link: `((role = 'CUSTOMER') = (customer_id is not null))`
- chk_user_hash: `(password_hash like '$2_$%')`
- chk_user_staff_link: `((role = 'SERVICE_STAFF') = (center_id is not null))`
- chk_user_tech_link: `((role = 'TECHNICIAN') = (technician_id is not null))`
