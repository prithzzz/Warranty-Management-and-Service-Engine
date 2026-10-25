-- Run from inside the database folder:   mysql -u root -p < build_all.sql

-- common
SOURCE common/create_database.sql
SOURCE common/test_framework.sql

-- sales module (Sales, Warranty and Recall)
SOURCE sales_module/tables.sql
SOURCE sales_module/procedures_triggers.sql
SOURCE sales_module/sample_data.sql
SOURCE sales_module/queries.sql
SOURCE sales_module/tests.sql

-- service module (Service, Repair and Claims)
SOURCE service_module/tables.sql
SOURCE service_module/procedures_triggers_views.sql
SOURCE service_module/sample_data.sql
SOURCE service_module/queries.sql
SOURCE service_module/tests.sql

SELECT owner AS module, COUNT(*) AS tests, SUM(outcome = 'PASS') AS passed
FROM test_result GROUP BY owner;
