# Warranty Management and Service Engine

DBMS Level 3 Project.

## About the project

The engine tracks every serial-numbered product unit from sale to service: who bought it, which warranty covers it, whether it falls inside a recall batch, and every repair, claim and replacement made on it. Business rules such as claim eligibility, recall blocking, stock limits and status workflow are enforced inside the database using constraints, triggers and stored procedures.

## Folder structure

```
database/
  build_all.sql            builds the whole database in the correct order
  build_all.sh             same, for Linux/macOS
  common/
    create_database.sql    creates the warranty_engine database
    test_framework.sql     helper procedures used by the test files
  sales_module/            Sales, Warranty and Recall
    tables.sql
    procedures_triggers.sql
    sample_data.sql
    queries.sql
    tests.sql
  service_module/          Service, Repair and Claims (added separately)
```

## Modules

| | Sales module | Service module |
|---|---|---|
| Tables | customer, product, product_model, serial_unit, purchase, purchase_item, warranty_plan, warranty, recall_campaign, recall_scope, recall_notification | service_center, technician, spare_part, service_request, repair, repair_part, warranty_claim, replacement, service_status_log, app_user |
| Functions | fn_has_active_warranty, fn_unit_under_recall | fn_repair_cost |
| Procedures | sp_register_sale, sp_generate_recall_notifications, sp_expire_warranties | sp_assign_technician, sp_file_warranty_claim, sp_complete_repair, sp_process_replacement |
| Views | v_warranty_overview, v_recall_affected_units | v_open_service_queue, v_technician_performance, v_part_reorder_alert |
| Other | full-text search on recalls, daily warranty expiry event | full-text search on issue descriptions, audit log, role-based users |
| Tests | 20 | 25 |

The sales module builds and runs on its own. The service module depends on it: its tables reference customer, serial_unit, warranty and recall_campaign, and its procedures call the sales module's functions. Its files are added to build_all.sql after the sales module block.

## Setup

Requirements: MySQL 8.0.16 or later.

```bash
cd database
mysql -u root -p < build_all.sql
```

Each run drops and recreates the warranty_engine database. The final output shows the test summary for each module (20 of 20 for SALES). Detailed results are stored in the test_result table.

Views and some queries use CURRENT_DATE, so values such as days_left depend on the day you run them.

Demo login accounts in app_user all use the password Password@123, stored as a bcrypt hash.

## Requirement coverage

| Requirement | Where |
|---|---|
| ER design, keys, relationships, constraints | sales_module/tables.sql, service_module/tables.sql |
| CREATE, ALTER, DROP, indexes, views | tables.sql and procedures_triggers.sql in both modules, staging table in service_module/queries.sql |
| INSERT, UPDATE, DELETE, JOIN, GROUP BY, HAVING, ORDER BY, subqueries | sample_data.sql and queries.sql in both modules |
| Advanced SQL | transactions, stored procedures and functions, triggers, views, indexing with EXPLAIN, full-text search, window functions, CTE, scheduled event |
| Roles | ADMIN, SERVICE_STAFF, TECHNICIAN, CUSTOMER in app_user |
| Database-level validation | CHECK, UNIQUE, FOREIGN KEY, ENUM, trigger checks |
| Test cases | tests.sql in both modules |

## Changes from the original ER diagram

1. WARRANTY_TYPE became warranty_plan (type, duration, claim limit, price), so one unit can hold a standard and an accidental damage plan together.
2. RECALL_PRODUCT became recall_scope, defined by model and manufacture date range instead of serial number ranges.
3. PURCHASE_ITEM no longer has quantity, since each row is one serial-numbered unit.
4. serial_unit has current_owner_id so ownership carries over after a replacement.
5. Added app_user for login and service_status_log for the audit trail.
6. A warranty claim is unique per service request, and replacement stores both the old and new unit.
