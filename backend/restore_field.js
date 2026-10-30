const mysql = require('mysql2/promise');
async function run() {
  const pool = mysql.createPool({ host: 'localhost', port: 3308, user: 'prosaha_user', password: 'prosaha_pass', database: 'prosaha' });
  
  await pool.query("INSERT INTO fields (id, name, description, capacity, price_per_hour, is_active) VALUES (2, 'Halı Saha INTER HALISAHA', 'Kapalı, UEFA Standartlarında profesyonel saha', 10, '4000.00', 1) ON DUPLICATE KEY UPDATE name='Halı Saha INTER HALISAHA'");
  
  console.log("Restored INTER HALISAHA");
  process.exit(0);
}
run();
