-- =====================================================================
-- common/test_framework.sql
-- Tiny test framework so negative tests (constraint and trigger
-- violations) can run in one script without stopping at the first error.
--   sp_expect_error(name, sql) : PASS if the statement raises an error
--   sp_expect_ok(name, sql)    : PASS if the statement succeeds
--   sp_assert(name, condition) : PASS if the SQL condition is true
-- =====================================================================
USE warranty_engine;

DROP TABLE IF EXISTS test_result;
CREATE TABLE test_result (
  test_id    INT AUTO_INCREMENT PRIMARY KEY,
  owner      VARCHAR(10)  NOT NULL,          -- which module the test belongs to
  test_name  VARCHAR(120) NOT NULL,
  expected   VARCHAR(10)  NOT NULL,
  outcome    ENUM('PASS','FAIL') NOT NULL,
  message    VARCHAR(500)
);

DROP PROCEDURE IF EXISTS sp_run_stmt;
DROP PROCEDURE IF EXISTS sp_expect_error;
DROP PROCEDURE IF EXISTS sp_expect_ok;
DROP PROCEDURE IF EXISTS sp_assert;

DELIMITER $$

-- runs one dynamic statement and returns the first error message (or NULL)
CREATE PROCEDURE sp_run_stmt(IN p_sql TEXT, OUT p_error VARCHAR(500))
BEGIN
  DECLARE v_msg VARCHAR(500);
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
  BEGIN
    GET DIAGNOSTICS CONDITION 1 v_msg = MESSAGE_TEXT;
    IF p_error IS NULL THEN SET p_error = v_msg; END IF;
  END;
  SET p_error = NULL;
  SET @t_sql = p_sql;
  PREPARE t_stmt FROM @t_sql;
  EXECUTE t_stmt;
  DEALLOCATE PREPARE t_stmt;
END$$

CREATE PROCEDURE sp_expect_error(IN p_module VARCHAR(10), IN p_name VARCHAR(120), IN p_sql TEXT)
BEGIN
  DECLARE v_err VARCHAR(500);
  CALL sp_run_stmt(p_sql, v_err);
  INSERT INTO test_result (owner, test_name, expected, outcome, message)
  VALUES (p_module, p_name, 'ERROR', IF(v_err IS NULL, 'FAIL', 'PASS'),
          COALESCE(v_err, 'Statement succeeded but should have failed'));
END$$

CREATE PROCEDURE sp_expect_ok(IN p_module VARCHAR(10), IN p_name VARCHAR(120), IN p_sql TEXT)
BEGIN
  DECLARE v_err VARCHAR(500);
  CALL sp_run_stmt(p_sql, v_err);
  INSERT INTO test_result (owner, test_name, expected, outcome, message)
  VALUES (p_module, p_name, 'OK', IF(v_err IS NULL, 'PASS', 'FAIL'), COALESCE(v_err, 'OK'));
END$$

CREATE PROCEDURE sp_assert(IN p_module VARCHAR(10), IN p_name VARCHAR(120), IN p_condition TEXT)
BEGIN
  DECLARE v_err VARCHAR(500);
  SET @t_ok = NULL;
  CALL sp_run_stmt(CONCAT('SELECT (', p_condition, ') INTO @t_ok'), v_err);
  INSERT INTO test_result (owner, test_name, expected, outcome, message)
  VALUES (p_module, p_name, 'TRUE', IF(v_err IS NULL AND @t_ok = 1, 'PASS', 'FAIL'),
          COALESCE(v_err, CONCAT('condition evaluated to ', COALESCE(@t_ok, 'NULL'))));
END$$

DELIMITER ;
