# 4. Data Dictionary: Sales, Warranty and Recall Module

Generated from the live MySQL schema (information_schema). PK means primary key; INDEX means an indexed column, usually a foreign key.

## customer

People who buy products. Contact details are validated by CHECK constraints.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| customer_id | int | NO | PK, auto increment |  |  |
| full_name | varchar(100) | NO |  |  |  |
| email | varchar(120) | NO | UNIQUE |  |  |
| phone | char(10) | NO | UNIQUE |  |  |
| address | varchar(255) | YES |  |  |  |
| city | varchar(60) | NO |  |  |  |
| preferred_channel | enum(EMAIL, SMS, APP) | NO |  | EMAIL |  |
| registered_on | date | NO |  | curdate() |  |

Check constraints:

- chk_customer_email: `regexp_like(email,'^[^@ ]+@[^@ ]+[.][a-z]{2,}$')`
- chk_customer_name: `(char_length(trim(full_name)) >= 2)`
- chk_customer_phone: `regexp_like(phone,'^[6-9][0-9]{9}$')`

## product

A product line from a brand, such as Samsung Galaxy S.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| product_id | int | NO | PK, auto increment |  |  |
| product_name | varchar(100) | NO |  |  |  |
| brand | varchar(60) | NO | INDEX |  |  |
| category | enum(SMARTPHONE, LAPTOP, TABLET, TELEVISION, APPLIANCE, WEARABLE, AUDIO) | NO |  |  |  |

## product_model

A specific model within a product line, with its launch date and MRP.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| model_id | int | NO | PK, auto increment |  |  |
| product_id | int | NO | INDEX |  | product.product_id |
| model_code | varchar(30) | NO | UNIQUE |  |  |
| model_name | varchar(100) | NO |  |  |  |
| launch_date | date | NO |  |  |  |
| mrp | decimal(10,2) | NO |  |  |  |

Check constraints:

- chk_model_mrp: `(mrp > 0)`

## serial_unit

One physical unit identified by its serial number. Warranties, recalls and service requests all refer to this table.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| serial_id | int | NO | PK, auto increment |  |  |
| serial_no | varchar(30) | NO | UNIQUE |  |  |
| model_id | int | NO | INDEX |  | product_model.model_id |
| manufacture_date | date | NO |  |  |  |
| status | enum(IN_STOCK, SOLD, REPLACED, SCRAPPED) | NO |  | IN_STOCK |  |
| current_owner_id | int | YES | INDEX |  | customer.customer_id |

Check constraints:

- chk_serial_owner: `(((status <> 'IN_STOCK') or (current_owner_id is null)) and ((status <> 'SOLD') or (current_owner_id is not null)))`

## purchase

An invoice. total_amount is kept in sync by triggers on purchase_item.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| purchase_id | int | NO | PK, auto increment |  |  |
| invoice_no | varchar(20) | NO | UNIQUE |  |  |
| customer_id | int | NO | INDEX |  | customer.customer_id |
| purchase_date | date | NO |  |  |  |
| channel | enum(ONLINE, RETAIL_STORE, DEALER) | NO |  |  |  |
| total_amount | decimal(12,2) | NO |  | 0.00 |  |

Check constraints:

- chk_purchase_total: `(total_amount >= 0)`

## purchase_item

One serial unit sold on an invoice. A unit can be sold only once.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| purchase_item_id | int | NO | PK, auto increment |  |  |
| purchase_id | int | NO | INDEX |  | purchase.purchase_id |
| serial_id | int | NO | UNIQUE |  | serial_unit.serial_id |
| unit_price | decimal(10,2) | NO |  |  |  |

Check constraints:

- chk_item_price: `(unit_price > 0)`

## warranty_plan

Catalogue of warranty plans (standard, extended, accidental damage).

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| plan_id | int | NO | PK, auto increment |  |  |
| plan_code | varchar(20) | NO | UNIQUE |  |  |
| plan_name | varchar(80) | NO |  |  |  |
| plan_type | enum(STANDARD, EXTENDED, ACCIDENTAL_DAMAGE) | NO |  |  |  |
| duration_months | tinyint unsigned | NO |  |  |  |
| max_claims | tinyint unsigned | NO |  | 3 |  |
| coverage_desc | varchar(255) | NO |  |  |  |
| price | decimal(10,2) | NO |  | 0.00 |  |

Check constraints:

- chk_plan_claims: `(max_claims >= 1)`
- chk_plan_duration: `(duration_months between 1 and 60)`
- chk_plan_price: `(price >= 0)`

## warranty

Coverage of one unit under one plan for a date range.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| warranty_id | int | NO | PK, auto increment |  |  |
| serial_id | int | NO | INDEX |  | serial_unit.serial_id |
| plan_id | int | NO | INDEX |  | warranty_plan.plan_id |
| start_date | date | NO |  |  |  |
| end_date | date | NO |  |  |  |
| status | enum(ACTIVE, EXPIRED, VOID) | NO | INDEX | ACTIVE |  |

Check constraints:

- chk_warranty_dates: `(end_date > start_date)`

## recall_campaign

A manufacturer recall announcement.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| recall_id | int | NO | PK, auto increment |  |  |
| recall_code | varchar(20) | NO | UNIQUE |  |  |
| title | varchar(150) | NO | INDEX |  |  |
| reason | text | NO |  |  |  |
| severity | enum(LOW, MEDIUM, HIGH, CRITICAL) | NO |  |  |  |
| remedy | enum(INSPECT, REPAIR, REPLACE, REFUND) | NO |  |  |  |
| announced_on | date | NO |  |  |  |
| status | enum(ANNOUNCED, ACTIVE, CLOSED) | NO |  | ANNOUNCED |  |

## recall_scope

Which model and manufacture date range a recall affects.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| scope_id | int | NO | PK, auto increment |  |  |
| recall_id | int | NO | INDEX |  | recall_campaign.recall_id |
| model_id | int | NO | INDEX |  | product_model.model_id |
| mfg_from | date | NO |  |  |  |
| mfg_to | date | NO |  |  |  |

Check constraints:

- chk_scope_range: `(mfg_to >= mfg_from)`

## recall_notification

One notice per affected unit, sent to its current owner.

| Column | Type | Null | Key | Default | References |
|---|---|---|---|---|---|
| notification_id | int | NO | PK, auto increment |  |  |
| recall_id | int | NO | INDEX |  | recall_campaign.recall_id |
| serial_id | int | NO | INDEX |  | serial_unit.serial_id |
| customer_id | int | NO | INDEX |  | customer.customer_id |
| channel | enum(EMAIL, SMS, APP) | NO |  | EMAIL |  |
| notified_at | datetime | NO |  | CURRENT_TIMESTAMP |  |
| status | enum(PENDING, SENT, ACKNOWLEDGED, RESOLVED) | NO |  | PENDING |  |
