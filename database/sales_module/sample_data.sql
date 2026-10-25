-- =====================================================================
-- sales_module/sample_data.sql
-- Sample data for the Sales, Warranty and Recall module
-- Run after 03 and 04 so that every row passes through the triggers.
-- =====================================================================
USE warranty_engine;

INSERT INTO customer (full_name, email, phone, address, city, preferred_channel, registered_on) VALUES
('Ananya Sharma',   'ananya.sharma@mail.com',   '9845012301', '12 4th Cross, Jayanagar',     'Bengaluru', 'EMAIL', '2023-11-20'),
('Rahul Menon',     'rahul.menon@mail.com',     '9886012302', '45 ITPL Main Rd, Whitefield', 'Bengaluru', 'SMS',   '2023-12-05'),
('Priya Hegde',     'priya.hegde@mail.com',     '9741012303', '8 Saraswathipuram',           'Mysuru',    'EMAIL', '2023-08-15'),
('Karthik Reddy',   'karthik.reddy@mail.com',   '9900012304', '221 HSR Layout Sector 2',     'Bengaluru', 'APP',   '2023-09-10'),
('Sneha Patil',     'sneha.patil@mail.com',     '8095012305', '19 Malleshwaram 8th Cross',   'Bengaluru', 'EMAIL', '2024-03-01'),
('Aditya Joshi',    'aditya.joshi@mail.com',    '7899012306', '6 Indiranagar 100ft Rd',      'Bengaluru', 'SMS',   '2024-04-10'),
('Nikhil Bhat',     'nikhil.bhat@mail.com',     '9620012307', '77 Basavanagudi',             'Bengaluru', 'EMAIL', '2024-05-02'),
('Divya Krishnan',  'divya.krishnan@mail.com',  '9444012308', '3 T Nagar Usman Rd',          'Chennai',   'EMAIL', '2024-06-18'),
('Rohan Desai',     'rohan.desai@mail.com',     '9008012309', '58 Koramangala 5th Block',    'Bengaluru', 'APP',   '2024-08-20'),
('Meghana Rao',     'meghana.rao@mail.com',     '9535012310', '102 Electronic City Ph 1',    'Bengaluru', 'EMAIL', '2024-09-14'),
('Farhan Ali',      'farhan.ali@mail.com',      '8147012311', '14 Frazer Town',              'Bengaluru', 'SMS',   '2024-10-25'),
('Lavanya Gowda',   'lavanya.gowda@mail.com',   '9972012312', '29 Vijayanagar 2nd Stage',    'Mysuru',    'EMAIL', '2025-01-15');

INSERT INTO product (product_name, brand, category) VALUES
('Galaxy S',                 'Samsung', 'SMARTPHONE'),
('iPhone',                   'Apple',   'SMARTPHONE'),
('Inspiron',                 'Dell',    'LAPTOP'),
('OLED evo',                 'LG',      'TELEVISION'),
('Double Door Refrigerator', 'LG',      'APPLIANCE'),
('Bravia',                   'Sony',    'TELEVISION'),
('WH Noise Cancelling',      'Sony',    'AUDIO');

INSERT INTO product_model (product_id, model_code, model_name, launch_date, mrp) VALUES
(1, 'SM-S921',    'Galaxy S24',              '2024-01-31',  79999.00),
(1, 'SM-S931',    'Galaxy S25',              '2025-02-07',  80999.00),
(2, 'A3090',      'iPhone 15',               '2023-09-22',  79900.00),
(2, 'A3287',      'iPhone 16',               '2024-09-20',  79900.00),
(3, 'INS-3530',   'Inspiron 15 3530',        '2023-06-01',  55990.00),
(3, 'INS-5440',   'Inspiron 14 5440',        '2024-03-01',  68990.00),
(4, 'OLED55C4',   'LG OLED evo C4 55',       '2024-04-15', 139990.00),
(5, 'GL-T382',    'LG 343L Frost Free',      '2023-03-01',  38990.00),
(6, 'K-55XR70',   'Bravia 7 55',             '2024-07-01', 149990.00),
(7, 'WH-1000XM5', 'WH-1000XM5',              '2022-05-20',  29990.00);

-- every unit starts IN_STOCK; the sale trigger marks it SOLD
INSERT INTO serial_unit (serial_no, model_id, manufacture_date) VALUES
('S24-24A0001',   1, '2024-02-10'), ('S24-24A0002',   1, '2024-03-05'),
('S24-24A0003',   1, '2024-03-20'), ('S24-24B0004',   1, '2024-06-12'),
('S24-24A0005',   1, '2024-04-02'), ('S24-24B0030',   1, '2024-07-01'),
('S25-25A0006',   2, '2025-03-01'), ('S25-25A0007',   2, '2025-03-01'),
('IP15-23K0008',  3, '2023-10-02'), ('IP15-23K0009',  3, '2023-11-15'),
('IP16-24L0010',  4, '2024-10-01'), ('IP16-24L0011',  4, '2024-11-20'),
('IP16-24L0012',  4, '2024-11-20'),
('INS35-23F0013', 5, '2023-07-10'), ('INS35-23F0014', 5, '2023-08-01'),
('INS54-24C0015', 6, '2024-04-01'), ('INS54-24C0016', 6, '2024-05-15'),
('INS54-24C0017', 6, '2024-05-15'),
('LGC4-24D0018',  7, '2024-05-10'), ('LGC4-24D0019',  7, '2024-06-01'),
('LGC4-24D0020',  7, '2024-06-01'),
('LGFR-23E0021',  8, '2023-05-12'), ('LGFR-23E0022',  8, '2023-06-20'),
('LGFR-23E0023',  8, '2023-10-01'), ('LGFR-23E0024',  8, '2023-07-07'),
('LGFR-24E0033',  8, '2024-01-10'),
('BR7-24G0025',   9, '2024-08-01'), ('BR7-24G0026',   9, '2024-08-01'),
('XM5-22H0027',  10, '2022-08-01'), ('XM5-23H0028',  10, '2023-01-10'),
('XM5-23H0029',  10, '2023-01-10');

INSERT INTO warranty_plan (plan_code, plan_name, plan_type, duration_months, max_claims, coverage_desc, price) VALUES
('STD12', 'Standard 12 Month',         'STANDARD',          12, 3, 'Manufacturing defects in parts and labour',              0.00),
('STD24', 'Standard 24 Month',         'STANDARD',          24, 3, 'Manufacturing defects for TVs and large appliances',    0.00),
('EXT36', 'Extended Care 36 Month',    'EXTENDED',          36, 5, 'Defects plus battery and wear-out cover for 3 years', 4999.00),
('ADP12', 'Accidental Damage 12 Month','ACCIDENTAL_DAMAGE', 12, 1, 'One accidental or liquid damage repair',              2499.00);

-- purchases (total_amount is filled by the purchase_item trigger)
INSERT INTO purchase (invoice_no, customer_id, purchase_date, channel) VALUES
('INV-2023-0001',  1, '2023-11-20', 'RETAIL_STORE'),
('INV-2023-0002',  2, '2023-12-05', 'ONLINE'),
('INV-2023-0003',  3, '2023-08-15', 'DEALER'),
('INV-2023-0004',  4, '2023-09-10', 'RETAIL_STORE'),
('INV-2024-0005',  5, '2024-03-01', 'ONLINE'),
('INV-2024-0006',  6, '2024-04-10', 'ONLINE'),
('INV-2024-0007',  7, '2024-05-02', 'RETAIL_STORE'),
('INV-2024-0008',  8, '2024-06-18', 'DEALER'),
('INV-2024-0009',  1, '2024-07-05', 'ONLINE'),
('INV-2024-0010',  9, '2024-08-20', 'RETAIL_STORE'),
('INV-2024-0011', 10, '2024-09-14', 'RETAIL_STORE'),
('INV-2024-0012', 11, '2024-10-25', 'ONLINE'),
('INV-2024-0013',  3, '2024-12-01', 'ONLINE'),
('INV-2025-0014', 12, '2025-01-15', 'RETAIL_STORE'),
('INV-2025-0015',  2, '2025-03-20', 'ONLINE'),
('INV-2025-0016',  5, '2025-06-05', 'DEALER'),
('INV-2025-0017',  9, '2025-11-11', 'ONLINE'),
('INV-2026-0018', 10, '2026-02-14', 'ONLINE'),
('INV-2026-0019',  4, '2026-08-30', 'RETAIL_STORE');

-- The sale trigger updates serial_unit, so the lookup is staged in a
-- temporary table first (MySQL forbids a trigger from updating a table that
-- the triggering INSERT ... SELECT is reading).
DROP TEMPORARY TABLE IF EXISTS tmp_sale_lines;
CREATE TEMPORARY TABLE tmp_sale_lines AS
SELECT p.purchase_id, s.serial_id, x.price
FROM (
  SELECT 'INV-2023-0001' AS inv, 'IP15-23K0008'  AS sn,  74999.00 AS price UNION ALL
  SELECT 'INV-2023-0002', 'INS35-23F0013',  52990.00 UNION ALL
  SELECT 'INV-2023-0003', 'LGFR-23E0021',   36990.00 UNION ALL
  SELECT 'INV-2023-0004', 'LGFR-23E0022',   36500.00 UNION ALL
  SELECT 'INV-2023-0004', 'XM5-22H0027',    26990.00 UNION ALL
  SELECT 'INV-2024-0005', 'S24-24A0001',    74999.00 UNION ALL
  SELECT 'INV-2024-0006', 'S24-24A0002',    72999.00 UNION ALL
  SELECT 'INV-2024-0007', 'S24-24A0003',    73999.00 UNION ALL
  SELECT 'INV-2024-0008', 'LGC4-24D0018',  129990.00 UNION ALL
  SELECT 'INV-2024-0009', 'INS54-24C0015',  64990.00 UNION ALL
  SELECT 'INV-2024-0010', 'S24-24B0004',    69999.00 UNION ALL
  SELECT 'INV-2024-0010', 'XM5-23H0028',    24990.00 UNION ALL
  SELECT 'INV-2024-0011', 'BR7-24G0025',   139990.00 UNION ALL
  SELECT 'INV-2024-0012', 'IP16-24L0010',   79900.00 UNION ALL
  SELECT 'INV-2024-0013', 'IP16-24L0011',   77900.00 UNION ALL
  SELECT 'INV-2025-0014', 'LGC4-24D0019',  124990.00 UNION ALL
  SELECT 'INV-2025-0015', 'S25-25A0006',    78999.00 UNION ALL
  SELECT 'INV-2025-0016', 'INS54-24C0016',  62990.00 UNION ALL
  SELECT 'INV-2025-0017', 'LGFR-23E0023',   34990.00 UNION ALL
  SELECT 'INV-2026-0018', 'INS35-23F0014',  45990.00 UNION ALL
  SELECT 'INV-2026-0019', 'IP15-23K0009',   59999.00
) AS x
JOIN purchase p    ON p.invoice_no = x.inv
JOIN serial_unit s ON s.serial_no = x.sn;

INSERT INTO purchase_item (purchase_id, serial_id, unit_price)
SELECT purchase_id, serial_id, price FROM tmp_sale_lines;

DROP TEMPORARY TABLE tmp_sale_lines;

-- warranties start on the purchase date; end_date is computed by trigger
INSERT INTO warranty (serial_id, plan_id, start_date, end_date)
SELECT s.serial_id, wp.plan_id, p.purchase_date, NULL
FROM (
  SELECT 'IP15-23K0008' AS sn, 'STD12' AS plan UNION ALL
  SELECT 'IP15-23K0008',  'ADP12' UNION ALL
  SELECT 'INS35-23F0013', 'STD12' UNION ALL
  SELECT 'INS35-23F0013', 'EXT36' UNION ALL
  SELECT 'LGFR-23E0021',  'STD24' UNION ALL
  SELECT 'LGFR-23E0022',  'STD24' UNION ALL
  SELECT 'XM5-22H0027',   'STD12' UNION ALL
  SELECT 'S24-24A0001',   'STD12' UNION ALL
  SELECT 'S24-24A0002',   'STD12' UNION ALL
  SELECT 'S24-24A0002',   'ADP12' UNION ALL
  SELECT 'S24-24A0003',   'EXT36' UNION ALL
  SELECT 'LGC4-24D0018',  'STD24' UNION ALL
  SELECT 'INS54-24C0015', 'STD12' UNION ALL
  SELECT 'S24-24B0004',   'STD12' UNION ALL
  SELECT 'XM5-23H0028',   'STD12' UNION ALL
  SELECT 'BR7-24G0025',   'STD24' UNION ALL
  SELECT 'IP16-24L0010',  'STD12' UNION ALL
  SELECT 'IP16-24L0010',  'ADP12' UNION ALL
  SELECT 'IP16-24L0011',  'EXT36' UNION ALL
  SELECT 'LGC4-24D0019',  'STD24' UNION ALL
  SELECT 'S25-25A0006',   'STD12' UNION ALL
  SELECT 'S25-25A0006',   'ADP12' UNION ALL
  SELECT 'INS54-24C0016', 'STD12' UNION ALL
  SELECT 'LGFR-23E0023',  'STD24' UNION ALL
  SELECT 'INS35-23F0014', 'STD12' UNION ALL
  SELECT 'IP15-23K0009',  'STD12'
) AS x
JOIN serial_unit s    ON s.serial_no = x.sn
JOIN purchase_item pi ON pi.serial_id = s.serial_id
JOIN purchase p       ON p.purchase_id = pi.purchase_id
JOIN warranty_plan wp ON wp.plan_code = x.plan;

CALL sp_expire_warranties();

-- recalls
INSERT INTO recall_campaign (recall_code, title, reason, severity, remedy, announced_on) VALUES
('RC-2023-002', 'LG refrigerator compressor relay overheating',
 'Compressor start relay in a batch of 343L frost free refrigerators may overheat and cause a burning smell. Relay to be replaced free of cost.',
 'HIGH', 'REPAIR', '2023-11-01'),
('RC-2024-001', 'Galaxy S24 battery swelling risk',
 'Batteries from one supplier batch may swell after repeated fast charging, lifting the back glass. Affected phones will be replaced.',
 'HIGH', 'REPLACE', '2024-07-01'),
('RC-2025-003', 'Inspiron 14 charging adapter inspection',
 'Some 65W charging adapters shipped with Inspiron 14 laptops may run hot. Adapters will be inspected and swapped if faulty.',
 'MEDIUM', 'INSPECT', '2025-09-01');

INSERT INTO recall_scope (recall_id, model_id, mfg_from, mfg_to)
SELECT rc.recall_id, pm.model_id, x.f, x.t
FROM (
  SELECT 'RC-2023-002' AS code, 'GL-T382' AS model, DATE '2023-04-01' AS f, DATE '2023-08-31' AS t UNION ALL
  SELECT 'RC-2024-001', 'SM-S921',  DATE '2024-02-01', DATE '2024-04-30' UNION ALL
  SELECT 'RC-2025-003', 'INS-5440', DATE '2024-03-01', DATE '2024-06-30'
) AS x
JOIN recall_campaign rc ON rc.recall_code = x.code
JOIN product_model pm   ON pm.model_code = x.model;

-- notify owners for the first two recalls (RC-2025-003 is left ANNOUNCED
-- so the procedure can be demonstrated live in sales_module/queries.sql)
CALL sp_generate_recall_notifications((SELECT recall_id FROM recall_campaign WHERE recall_code = 'RC-2023-002'), @n1);
CALL sp_generate_recall_notifications((SELECT recall_id FROM recall_campaign WHERE recall_code = 'RC-2024-001'), @n2);

UPDATE recall_notification n
JOIN serial_unit s ON s.serial_id = n.serial_id
SET n.status = CASE s.serial_no
                 WHEN 'LGFR-23E0021' THEN 'RESOLVED'
                 WHEN 'LGFR-23E0022' THEN 'RESOLVED'
                 WHEN 'S24-24A0001'  THEN 'ACKNOWLEDGED'
                 ELSE 'SENT' END;
