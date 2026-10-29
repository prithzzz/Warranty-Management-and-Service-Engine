// MySQL connection pool and helpers. Credentials come from .env.local.
import mysql from 'mysql2/promise';

const globalForDb = globalThis;

export const pool =
  globalForDb.mysqlPool ||
  mysql.createPool({
    host: process.env.MYSQL_HOST,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE,
    connectionLimit: 10,
    dateStrings: true,        // return DATE/DATETIME as plain strings
    decimalNumbers: true      // return DECIMAL as numbers
  });

if (process.env.NODE_ENV !== 'production') globalForDb.mysqlPool = pool;

// Run one parameterised query and return the rows.
export async function query(sql, params = []) {
  const [rows] = await pool.query(sql, params);
  return rows;
}

// Call a stored procedure that has OUT parameters.
// Example: callProcedure('sp_register_sale', [1, 'INV-1', ...], ['purchase_id'])
// returns { purchase_id: 21 }
export async function callProcedure(name, inArgs, outNames = []) {
  const conn = await pool.getConnection();
  try {
    const placeholders = inArgs.map(() => '?')
      .concat(outNames.map((n) => `@out_${n}`))
      .join(', ');
    await conn.query(`CALL ${name}(${placeholders})`, inArgs);
    if (outNames.length === 0) return {};
    const [rows] = await conn.query(
      'SELECT ' + outNames.map((n) => `@out_${n} AS ${n}`).join(', ')
    );
    return rows[0];
  } finally {
    conn.release();
  }
}

// Turn database errors into a clean message for the user.
// SIGNAL messages from triggers/procedures and CHECK/UNIQUE/FK errors all
// come through here, so validation done in MySQL reaches the UI as-is.
export function dbErrorMessage(err) {
  if (!err) return 'Unknown error';
  if (err.sqlState === '45000') return err.sqlMessage;               // our SIGNALs
  if (err.code === 'ER_DUP_ENTRY') return 'This record already exists: ' + err.sqlMessage;
  if (err.code === 'ER_CHECK_CONSTRAINT_VIOLATED') return 'Invalid value: ' + err.sqlMessage;
  if (err.code && err.code.startsWith('ER_NO_REFERENCED_ROW')) return 'A referenced record does not exist';
  if (err.code && err.code.startsWith('ER_ROW_IS_REFERENCED')) return 'This record is in use and cannot be removed';
  return err.sqlMessage || err.message || 'Database error';
}
