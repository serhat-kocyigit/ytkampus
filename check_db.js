const mysql = require('mysql2/promise');

async function check() {
  const pool = mysql.createPool({ host: 'localhost', port: 3308, user: 'prosaha_user', password: 'prosaha_pass', database: 'prosaha' });
  const [rows] = await pool.query('SELECT id, full_name, email FROM users');
  console.log(JSON.stringify(rows, null, 2));
  process.exit(0);
}
check();
