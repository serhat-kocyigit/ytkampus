const mysql = require('mysql2/promise');
async function run() {
  const pool = mysql.createPool({ host: 'localhost', port: 3308, user: 'prosaha_user', password: 'prosaha_pass', database: 'prosaha' });
  
  // Delete INTER HALISAHA
  await pool.query('DELETE FROM fields WHERE id = 2');
  
  // Rename Halı Saha to Futbol Sahası
  await pool.query('UPDATE fields SET name = "Futbol Sahası" WHERE id = 1');
  
  // Also clean up YT KAMPUS suffix if they just wanted "Futbol Sahası"
  
  console.log("Updated fields!");
  process.exit(0);
}
run();
