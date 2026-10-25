
USE warranty_engine;

INSERT INTO service_center (center_code, center_name, city, address, phone, email) VALUES
('BLR-JN', 'Jayanagar Service Hub',  'Bengaluru', '22 11th Main, Jayanagar 4th Block', '8041234501', 'jayanagar@wmse.in'),
('BLR-WF', 'Whitefield Care Point',  'Bengaluru', '7 Hope Farm Junction, Whitefield',  '8041234502', 'whitefield@wmse.in'),
('MYS-01', 'Mysuru Service Centre',  'Mysuru',    '15 Sayyaji Rao Road',               '8212345603', 'mysuru@wmse.in'),
('CHN-01', 'Chennai T Nagar Centre', 'Chennai',   '40 Pondy Bazaar, T Nagar',          '4423456704', 'chennai@wmse.in');

INSERT INTO technician (center_id, full_name, phone, email, skill_level, specialization) VALUES
(1, 'Arjun Rao',           '9845100001', 'arjun.rao@wmse.in',       'EXPERT', 'SMARTPHONE'),
(1, 'Meera Iyer',          '9845100002', 'meera.iyer@wmse.in',      'SENIOR', 'LAPTOP'),
(1, 'Kiran Gowda',         '9845100003', 'kiran.gowda@wmse.in',     'JUNIOR', 'APPLIANCE'),
(2, 'Vikram Shetty',       '9845100004', 'vikram.shetty@wmse.in',   'EXPERT', 'TELEVISION'),
(2, 'Divya Nair',          '9845100005', 'divya.nair@wmse.in',      'SENIOR', 'SMARTPHONE'),
(2, 'Rohit Kulkarni',      '9845100006', 'rohit.kulkarni@wmse.in',  'JUNIOR', 'LAPTOP'),
(3, 'Suresh Kumar',        '9845100007', 'suresh.kumar@wmse.in',    'SENIOR', 'APPLIANCE'),
(3, 'Anitha Ramesh',       '9845100008', 'anitha.ramesh@wmse.in',   'JUNIOR', 'TELEVISION'),
(4, 'Karthik Subramanian', '9445100009', 'karthik.s@wmse.in',       'EXPERT', 'TELEVISION'),
(4, 'Lakshmi Venkat',      '9445100010', 'lakshmi.venkat@wmse.in',  'SENIOR', 'SMARTPHONE');

INSERT INTO spare_part (part_code, part_name, part_category, unit_price, stock_qty, reorder_level) VALUES
('PRT-DSP-IP15', 'iPhone 15 OLED display assembly',     'DISPLAY',    18500.00,  6, 3),
('PRT-DSP-S24',  'Galaxy S24 AMOLED display',           'DISPLAY',    16800.00,  4, 3),
('PRT-BAT-S24',  'Galaxy S24 battery 4000mAh',          'BATTERY',     3200.00,  3, 5),
('PRT-BAT-IP15', 'iPhone 15 battery',                   'BATTERY',     4500.00,  8, 4),
('PRT-BAT-INS',  'Inspiron 3 cell battery',             'BATTERY',     5200.00,  5, 3),
('PRT-HNG-INS',  'Inspiron hinge kit',                  'BODY',        1800.00, 10, 4),
('PRT-ADP-65W',  '65W USB-C charging adapter',          'CHARGING',    2100.00,  2, 5),
('PRT-PNL-C4',   'LG C4 55 inch OLED panel',            'DISPLAY',    68000.00,  2, 1),
('PRT-PSU-C4',   'LG C4 power supply board',            'BOARD',       7400.00,  3, 2),
('PRT-SPK-BR7',  'Bravia 7 speaker module',             'AUDIO',       3900.00,  4, 2),
('PRT-RLY-LGFR', 'Refrigerator compressor start relay', 'COMPRESSOR',   950.00, 20, 10),
('PRT-CMP-LGFR', 'Refrigerator inverter compressor',    'COMPRESSOR', 11500.00,  2, 2),
('PRT-GLS-S24',  'Galaxy S24 back glass',               'BODY',        2400.00,  7, 3),
('PRT-CAM-IP16', 'iPhone 16 rear camera module',        'CAMERA',      9800.00,  3, 2),
('PRT-CHG-IP16', 'iPhone 16 charging port flex',        'CHARGING',    2600.00,  5, 3);

-- service requests 
INSERT INTO service_request (customer_id, serial_id, center_id, request_date, issue_type,
                             recall_id, issue_description, priority)
SELECT x.cust, s.serial_id, sc.center_id, x.dt, x.itype, rc.recall_id, x.descr, x.prio
FROM (
  SELECT 1 AS ord, 1 AS cust, 'IP15-23K0008' AS sn, 'BLR-JN' AS ctr, '2024-02-10 11:15:00' AS dt, 'DISPLAY' AS itype, NULL AS rcode,
         'Screen flickers and shows green lines after a few minutes of use' AS descr, 'HIGH' AS prio UNION ALL
  SELECT 2, 3, 'LGFR-23E0021', 'MYS-01', '2023-12-02 09:30:00', 'RECALL_FIX', 'RC-2023-002',
         'Recall notice received, burning smell near the compressor, relay replacement requested', 'HIGH' UNION ALL
  SELECT 3, 4, 'LGFR-23E0022', 'BLR-WF', '2023-12-10 14:00:00', 'RECALL_FIX', 'RC-2023-002',
         'Recall notice received, requesting compressor relay replacement', 'MEDIUM' UNION ALL
  SELECT 4, 6, 'S24-24A0002', 'BLR-JN', '2024-09-01 18:20:00', 'PHYSICAL_DAMAGE', NULL,
         'Phone dropped on tiles, back glass cracked but display still works', 'MEDIUM' UNION ALL
  SELECT 5, 2, 'INS35-23F0013', 'BLR-WF', '2024-10-05 10:05:00', 'BATTERY', NULL,
         'Laptop battery drains from full to zero in under one hour', 'MEDIUM' UNION ALL
  SELECT 6, 8, 'LGC4-24D0018', 'CHN-01', '2025-03-11 12:40:00', 'DISPLAY', NULL,
         'Vertical lines across the OLED panel and a dead pixel cluster', 'URGENT' UNION ALL
  SELECT 7, 9, 'S24-24B0004', 'BLR-JN', '2025-01-20 16:00:00', 'SOFTWARE', NULL,
         'Phone stuck in a boot loop after the latest system update', 'LOW' UNION ALL
  SELECT 8, 10, 'BR7-24G0025', 'BLR-WF', '2025-12-02 19:10:00', 'HARDWARE', NULL,
         'No sound from the built in speakers, HDMI audio output works fine', 'MEDIUM' UNION ALL
  SELECT 9, 11, 'IP16-24L0010', 'BLR-JN', '2026-01-15 13:25:00', 'PHYSICAL_DAMAGE', NULL,
         'Phone fell into water, charging port not working and screen is dim', 'HIGH' UNION ALL
  SELECT 10, 12, 'LGC4-24D0019', 'MYS-01', '2026-09-28 10:00:00', 'HARDWARE', NULL,
         'TV does not power on, standby light blinks red twice', 'HIGH' UNION ALL
  SELECT 11, 7, 'S24-24A0003', 'BLR-JN', '2026-10-18 09:45:00', 'RECALL_FIX', 'RC-2024-001',
         'Battery swelling and back panel lifting at the edges, recalled unit', 'URGENT' UNION ALL
  SELECT 12, 9, 'LGFR-23E0023', 'BLR-JN', '2026-10-20 08:30:00', 'HARDWARE', NULL,
         'Refrigerator not cooling, compressor runs continuously and is noisy', 'HIGH' UNION ALL
  SELECT 13, 10, 'INS35-23F0014', 'BLR-WF', '2026-10-22 15:15:00', 'HARDWARE', NULL,
         'Left hinge is loose and the screen wobbles when the lid is opened', 'LOW' UNION ALL
  SELECT 14, 4, 'IP15-23K0009', 'BLR-WF', '2026-10-23 11:00:00', 'BATTERY', NULL,
         'Battery health dropped quickly and the phone shuts down at 20 percent', 'MEDIUM' UNION ALL
  SELECT 15, 3, 'IP16-24L0011', 'MYS-01', '2026-07-10 17:30:00', 'HARDWARE', NULL,
         'Rear camera images are blurry and autofocus keeps hunting', 'MEDIUM' UNION ALL
  SELECT 16, 5, 'INS54-24C0016', 'BLR-JN', '2025-09-15 12:00:00', 'OTHER', NULL,
         'Charging adapter becomes very hot during use, customer worried after recall news', 'MEDIUM' UNION ALL
  SELECT 17, 1, 'IP15-23K0008', 'BLR-JN', '2024-10-02 10:00:00', 'BATTERY', NULL,
         'Battery drains fast and the phone heats up while charging', 'LOW'
) AS x
JOIN serial_unit s       ON s.serial_no = x.sn
JOIN service_center sc   ON sc.center_code = x.ctr
LEFT JOIN recall_campaign rc ON rc.recall_code = x.rcode
ORDER BY x.ord;

-- repairs opened (trigger moves each request to ASSIGNED / IN_PROGRESS)
INSERT INTO repair (request_id, technician_id, assigned_at, status) VALUES
( 1, 1, '2024-02-10 12:00:00', 'IN_PROGRESS'),
( 2, 7, '2023-12-02 11:00:00', 'IN_PROGRESS'),
( 3, 4, '2023-12-10 15:00:00', 'IN_PROGRESS'),
( 4, 1, '2024-09-02 10:00:00', 'IN_PROGRESS'),
( 5, 6, '2024-10-05 12:00:00', 'IN_PROGRESS'),
( 6, 9, '2025-03-11 14:00:00', 'IN_PROGRESS'),
( 7, 1, '2025-01-20 16:30:00', 'IN_PROGRESS'),
( 8, 4, '2025-12-03 10:00:00', 'IN_PROGRESS'),
( 9, 1, '2026-01-15 14:00:00', 'IN_PROGRESS'),
(10, 8, '2026-09-28 11:30:00', 'IN_PROGRESS'),
(14, 5, '2026-10-23 12:00:00', 'ASSIGNED'),
(15, 7, '2026-07-11 10:00:00', 'IN_PROGRESS'),
(17, 1, '2024-10-02 11:00:00', 'IN_PROGRESS');

-- parts used (unit_price NULL means "use catalogue price"; trigger fills it in and reduces stock). Staged in a temporary table because the stock trigger updates spare_part, which the INSERT...SELECT would be reading.
DROP TEMPORARY TABLE IF EXISTS tmp_parts_used;
CREATE TEMPORARY TABLE tmp_parts_used AS
SELECT x.rid, sp.part_id, x.qty
FROM (
  SELECT  1 AS rid, 'PRT-DSP-IP15' AS code, 1 AS qty UNION ALL
  SELECT  2, 'PRT-RLY-LGFR', 1 UNION ALL
  SELECT  3, 'PRT-RLY-LGFR', 1 UNION ALL
  SELECT  4, 'PRT-GLS-S24',  1 UNION ALL
  SELECT  5, 'PRT-BAT-INS',  1 UNION ALL
  SELECT  6, 'PRT-PNL-C4',   1 UNION ALL
  SELECT  8, 'PRT-SPK-BR7',  2 UNION ALL
  SELECT  9, 'PRT-CHG-IP16', 1 UNION ALL
  SELECT 10, 'PRT-PSU-C4',   1 UNION ALL
  SELECT 12, 'PRT-CAM-IP16', 1 UNION ALL
  SELECT 13, 'PRT-BAT-IP15', 1
) AS x
JOIN spare_part sp ON sp.part_code = x.code;

INSERT INTO repair_part (repair_id, part_id, quantity, unit_price)
SELECT rid, part_id, qty, NULL FROM tmp_parts_used;

DROP TEMPORARY TABLE tmp_parts_used;

-- warranty claims filed through the procedure (it picks the right warranty)
CALL sp_file_warranty_claim( 1, 'REPAIR',      @c);
CALL sp_file_warranty_claim( 4, 'REPAIR',      @c);
CALL sp_file_warranty_claim( 5, 'REPAIR',      @c);
CALL sp_file_warranty_claim( 6, 'REPAIR',      @c);
CALL sp_file_warranty_claim( 7, 'REPAIR',      @c);
CALL sp_file_warranty_claim( 8, 'REPAIR',      @c);
CALL sp_file_warranty_claim(10, 'REPAIR',      @c);
CALL sp_file_warranty_claim(11, 'REPLACEMENT', @c);
CALL sp_file_warranty_claim(15, 'REPAIR',      @c);
CALL sp_file_warranty_claim(17, 'REPAIR',      @c);

-- claim decisions
UPDATE warranty_claim SET status = 'APPROVED'
WHERE request_id IN (1, 4, 5, 6, 8, 11, 15, 17);

UPDATE warranty_claim
SET status = 'REJECTED', remarks = 'Software issue fixed by reflashing firmware, no hardware fault found'
WHERE request_id = 7;

-- repairs finished (triggers complete the request and settle approved claims)
UPDATE repair r
JOIN (
  SELECT  1 AS rid, '2024-02-12 17:00:00' AS done,  1200.00 AS labour, 'Replaced display assembly, tested for 2 hours' AS notes UNION ALL
  SELECT  2, '2023-12-03 13:00:00',    0.00, 'Recall fix: compressor relay replaced free of cost' UNION ALL
  SELECT  3, '2023-12-11 12:00:00',    0.00, 'Recall fix: compressor relay replaced free of cost' UNION ALL
  SELECT  4, '2024-09-03 15:30:00',   800.00, 'Back glass replaced under accidental damage plan' UNION ALL
  SELECT  5, '2024-10-07 11:00:00',   600.00, 'Battery replaced, calibration done' UNION ALL
  SELECT  6, '2025-03-15 18:00:00',  2500.00, 'OLED panel replaced on site' UNION ALL
  SELECT  7, '2025-01-20 18:00:00',   499.00, 'Firmware reflashed, data backed up first' UNION ALL
  SELECT  8, '2025-12-04 16:00:00',  1000.00, 'Both speaker modules replaced' UNION ALL
  SELECT  9, '2026-01-18 12:00:00',  1500.00, 'Charging flex replaced, board cleaned, paid repair' UNION ALL
  SELECT 12, '2026-07-12 17:00:00',   900.00, 'Rear camera module replaced' UNION ALL
  SELECT 13, '2024-10-03 12:00:00',   300.00, 'Battery replaced, second visit for this unit'
) AS d ON d.rid = r.repair_id
SET r.status = 'COMPLETED', r.completed_at = d.done,
    r.labour_charge = d.labour, r.resolution_notes = d.notes;

-- older completed jobs are closed after customer pickup
UPDATE service_request SET status = 'CLOSED'
WHERE status = 'COMPLETED' AND request_date < '2026-01-01';

-- customer cancelled request 16 the next day
UPDATE service_request SET status = 'CANCELLED', closed_at = '2025-09-16 10:00:00'
WHERE request_id = 16;

-- recalled phone replaced with a new unit (multi-table transaction)
SET @repl_claim = (SELECT claim_id FROM warranty_claim WHERE request_id = 11);
CALL sp_process_replacement(@repl_claim, 'S24-24B0030');

-- login accounts (password for all demo users: Password@123, bcrypt cost 10)
SET @pw = '$2b$10$yp9QgjK9bvRf3hdkL51b/ufzasqAglQcqdAKDZz2B1cHXdeu/R1Ca';
INSERT INTO app_user (username, email, password_hash, role, customer_id, technician_id, center_id) VALUES
('admin',            'admin@wmse.in',            @pw, 'ADMIN',         NULL, NULL, NULL),
('staff.jayanagar',  'staff.jn@wmse.in',         @pw, 'SERVICE_STAFF', NULL, NULL, 1),
('staff.whitefield', 'staff.wf@wmse.in',         @pw, 'SERVICE_STAFF', NULL, NULL, 2),
('tech.arjun',       'arjun.rao@wmse.in',        @pw, 'TECHNICIAN',    NULL, 1,    NULL),
('tech.vikram',      'vikram.shetty@wmse.in',    @pw, 'TECHNICIAN',    NULL, 4,    NULL),
('tech.suresh',      'suresh.kumar@wmse.in',     @pw, 'TECHNICIAN',    NULL, 7,    NULL),
('ananya',           'ananya.sharma@mail.com',   @pw, 'CUSTOMER',      1,    NULL, NULL),
('rahul',            'rahul.menon@mail.com',     @pw, 'CUSTOMER',      2,    NULL, NULL),
('priya',            'priya.hegde@mail.com',     @pw, 'CUSTOMER',      3,    NULL, NULL),
('karthik',          'karthik.reddy@mail.com',   @pw, 'CUSTOMER',      4,    NULL, NULL),
('nikhil',           'nikhil.bhat@mail.com',     @pw, 'CUSTOMER',      7,    NULL, NULL);
