const mysql = require('mysql2/promise');

async function fix() {
  const pool = mysql.createPool({
    host: 'localhost',
    port: 3308,
    user: 'prosaha_user',
    password: 'prosaha_pass',
    database: 'prosaha'
  });

  await pool.query("UPDATE fields SET description = 'Akustik yalıtımlı müzik stüdyosu' WHERE id = 14");
  await pool.query("UPDATE fields SET description = 'Profesyonel sanat ve resim atölyesi' WHERE id = 15");
  await pool.query("UPDATE fields SET description = 'Geniş aynalı dans ve bale salonu' WHERE id = 16");
  
  // also fix any other potential mojibake if the names got mangled
  await pool.query("UPDATE fields SET name = 'YT KAMPUS Sanat (Resim)' WHERE id = 15");
  
  console.log("Fixed!");
  process.exit(0);
}

fix().catch(console.error);
