/**
 * MySQL Veritabanı Bağlantı Havuzu
 * mysql2/promise ile async/await desteği sağlar
 */
const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '..', '.env') });

const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'halisaha_scoreboard',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  charset: 'utf8mb4'
});

/**
 * Veritabanı bağlantısını test eder
 */
async function testConnection() {
  try {
    const connection = await pool.getConnection();
    console.log('✅ MySQL bağlantısı başarılı');
    connection.release();
    return true;
  } catch (error) {
    console.error('❌ MySQL bağlantı hatası:', error.message);
    return false;
  }
}

async function ensurePlayerPhotoColumn() {
  try {
    await pool.query('ALTER TABLE players ADD COLUMN photo_path VARCHAR(255) DEFAULT NULL');
    console.log('✅ Oyuncu fotoğraf alanı eklendi');
  } catch (error) {
    if (error.code !== 'ER_DUP_FIELDNAME') console.error('⚠️ Oyuncu fotoğraf alanı kontrol edilemedi:', error.message);
  }
}

module.exports = { pool, testConnection, ensurePlayerPhotoColumn };
