const express = require('express');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const fsModule = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const crypto = require('crypto');
const { registerPublicVideoClips } = require('./public-video-clips');

const DOWNLOADED_VIDEO_WATERMARK = "drawtext=fontfile=/usr/share/fonts/TTF/DejaVuSans.ttf:text='YT Kampüs':fontcolor=white:fontsize=h/18:x=(w-text_w)/2:y=(h-text_h)/2:alpha=0.14+0.04*sin(t*2):shadowcolor=black@0.18:shadowx=2:shadowy=2";

const app = express();
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET || JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET en az 32 karakter olmalı ve ortam değişkeninden gelmelidir');
}
const PAYMENT_BASE_URL = String(process.env.PAYMENT_BASE_URL || 'http://localhost:8085').replace(/\/$/, '');
// The checkout form can return through a dedicated HTTPS callback endpoint while
// the local application continues to run on its normal address.
const PAYMENT_CALLBACK_BASE_URL = String(process.env.PAYMENT_CALLBACK_BASE_URL || PAYMENT_BASE_URL).replace(/\/$/, '');
const PAYMENT_CALLBACK_URL = `${PAYMENT_CALLBACK_BASE_URL}/api/payment/callback`;
// Native clients intercept this path after a successful checkout and return to
// their own panel. In an ordinary browser the GET handler below redirects to
// the same user dashboard.
const PAYMENT_PANEL_URL = `${PAYMENT_BASE_URL}/api/payment/callback?return=panel`;
const PAYMENT_BROWSER_RETURN_URL = String(process.env.PAYMENT_BROWSER_RETURN_URL || 'http://localhost:8085').replace(/\/$/, '');
const PAYMENT_BROWSER_PANEL_URL = `${PAYMENT_BROWSER_RETURN_URL}/api/payment/callback?return=panel`;
const CORS_ORIGINS = String(process.env.CORS_ORIGIN || PAYMENT_BASE_URL).split(',').map(origin => origin.trim()).filter(Boolean);
const paymentUrl = new URL(PAYMENT_BASE_URL);
const isPrivateNetworkHost = (host) => {
    if (['localhost', '127.0.0.1', '::1'].includes(host)) return true;
    if (/^10\./.test(host) || /^192\.168\./.test(host)) return true;
    const private172 = /^172\.(\d{1,3})\./.exec(host);
    return private172 && Number(private172[1]) >= 16 && Number(private172[1]) <= 31;
};
const isLocalPaymentHost = isPrivateNetworkHost(paymentUrl.hostname);
function isAllowedOrigin(origin) {
    if (CORS_ORIGINS.includes(origin)) return true;
    if (!isLocalPaymentHost) return false;
    try {
        const url = new URL(origin);
        return url.protocol === 'http:' && isPrivateNetworkHost(url.hostname);
    } catch { return false; }
}
if (!isLocalPaymentHost && paymentUrl.protocol !== 'https:') {
    throw new Error('Canlı ödeme için PAYMENT_BASE_URL HTTPS olmalıdır');
}
// iyzico'nun CheckoutForm şeması bu alanı zorunlu kılar. Kullanıcı T.C. kimlik
// numarası toplanmaz veya saklanmaz; bu yalnızca sağlayıcının test şeması için
// kullanılan sabit teknik değerdir.
const IYZICO_TECHNICAL_IDENTITY = '11111111111';
const SITE_IMAGE_KEYS = new Set(['site_logo', 'hero_logo', 'hero_image', 'academy_logo', 'about_image', 'team_image', 'academy_tennis', 'academy_inter', 'academy_art', 'academy_dance', 'academy_language', 'academy_kids', 'gallery_21', 'gallery_22', 'gallery_23', 'gallery_24', 'gallery_25', 'gallery_26', 'gallery_27', 'gallery_28']);
const AUTH_COOKIE = 'prosaha_session';
const authCookieOptions = Object.freeze({ httpOnly: true, sameSite: 'strict', secure: !isLocalPaymentHost, maxAge: 2 * 60 * 60 * 1000, path: '/' });
// Native clients keep their short-lived access token in the platform secure
// keystore. Browser sessions remain HttpOnly-cookie based and never receive a
// token in JSON.
const isNativeMobileClient = (req) => req.get('X-YT-Kampus-Client') === 'mobile';
function cookieValue(req, name) {
    const prefix = `${name}=`;
    const item = String(req.headers.cookie || '').split(';').map(value => value.trim()).find(value => value.startsWith(prefix));
    return item ? decodeURIComponent(item.slice(prefix.length)) : null;
}
function issueSession(res, token) { res.cookie(AUTH_COOKIE, token, authCookieOptions); }

app.set('trust proxy', 1);
app.use(cors({
    origin(origin, callback) {
        if (!origin || isAllowedOrigin(origin)) return callback(null, true);
        callback(null, false);
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE'],
    // Mobil istemci, çerezli web oturumundan farklı olarak Bearer token
    // döndürülebilmesi için bu tanımlayıcıyı yollar.
    allowedHeaders: ['Content-Type', 'Authorization', 'X-YT-Kampus-Client']
}));
// CORS bir yetkilendirme mekanizması değildir. Çerezli oturumlarda tarayıcıdan
// gelen durum değiştiren isteklerin yalnızca tanımlı origin'lerden gelmesini zorunlu kıl.
app.use((req, res, next) => {
    if (!['POST', 'PATCH', 'PUT', 'DELETE'].includes(req.method) || !req.headers.origin) return next();
    // Ödeme sağlayıcısı tarayıcı üzerinden callback POST'u gönderebilir. Asıl
    // güvenlik tokenın İyzico'dan sunucu tarafında tekrar doğrulanmasıdır.
    if (req.path === '/api/payment/callback' || isAllowedOrigin(req.headers.origin)) return next();
    return res.status(403).json({ error: 'İstek kaynağına izin verilmiyor' });
});
app.use(express.json({ limit: '100kb' }));
app.use(express.urlencoded({ extended: true, limit: '100kb' }));
app.disable('x-powered-by');
app.use((req, res, next) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
    if (req.path.startsWith('/api/payment/')) res.setHeader('Cache-Control', 'no-store');
    next();
});

const authAttempts = new Map();
const apiAttempts = new Map();
function fixedWindowRateLimit(store, limit, windowMs, keyForRequest) {
    return (req, res, next) => {
        const key = keyForRequest(req);
        const now = Date.now();
        const entry = store.get(key) || { count: 0, startedAt: now };
        if (now - entry.startedAt >= windowMs) { entry.count = 0; entry.startedAt = now; }
        entry.count += 1;
        store.set(key, entry);
        if (entry.count > limit) {
            res.setHeader('Retry-After', Math.ceil((windowMs - (now - entry.startedAt)) / 1000));
            return res.status(429).json({ error: 'Çok fazla istek yapıldı. Lütfen kısa süre sonra tekrar deneyin.' });
        }
        next();
    };
}
function authRateLimit(req, res, next) {
    const email = normalizeEmail(req.body?.email);
    const key = `${req.ip}:${email}`;
    const now = Date.now();
    const attempt = authAttempts.get(key) || { count: 0, startedAt: now };
    if (now - attempt.startedAt > 15 * 60 * 1000) {
        attempt.count = 0;
        attempt.startedAt = now;
    }
    attempt.count += 1;
    authAttempts.set(key, attempt);
    if (attempt.count > 10) return res.status(429).json({ error: 'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.' });
    next();
}
const paymentRateLimit = fixedWindowRateLimit(apiAttempts, 20, 15 * 60 * 1000, req => `payment:${req.ip}:${req.user?.id || 'anonymous'}`);
// Ödeme formu açıkken istemci, İyzico sonucunu arka planda kontrol eder. Bu
// kontrolleri ödeme başlatma kotasına dahil etmek tek bir ödeme oturumunun
// kendi kendini 429'a düşürmesine yol açıyordu.
const paymentStatusRateLimit = fixedWindowRateLimit(apiAttempts, 180, 15 * 60 * 1000, req => `payment-status:${req.ip}:${req.user?.id || 'anonymous'}:${req.params.intentId || ''}`);

// ─── DB Connection Pool ────────────────────────────────────────────────────────
let pool;
async function connectDB() {
    let retries = 10;
    while (retries) {
        try {
            pool = mysql.createPool({
                host: process.env.DB_HOST || 'localhost',
                user: process.env.DB_USER || 'prosaha_user',
                password: process.env.DB_PASSWORD || 'prosaha_pass',
                database: process.env.DB_NAME || 'prosaha',
                waitForConnections: true,
                connectionLimit: 10,
            });
            await pool.query('SELECT 1');
            await ensureSportsFields();
            await ensurePaymentColumns();
            await ensurePaymentIntentsTable();
            await ensureAcademyPaymentIntentsTable();
            await ensureFieldMediaColumn();
            await ensureSeparateFieldImages();
            await ensureSiteSettingsTable();
            await migrateLegacyHeroImage();
            await restoreInterCatalogBallOnce();
            await ensureMatchVideoRetentionColumn();
            await ensureVideoClipsTable();
            await ensureNotificationsTable();
            await ensureAuditLogTable();
            await ensureReservationCreatorColumn();
            await ensureReservationIndexes();
            await removeNationalIdentityColumn();
            await cleanupExpiredMedia();
            await cleanupExpiredPayments();
            setInterval(() => cleanupExpiredMedia().catch(err => console.error('Medya temizleme hatası:', err.message)), 6 * 60 * 60 * 1000).unref();
            setInterval(() => cleanupExpiredPayments().catch(err => console.error('Ödeme temizleme hatası:', err.message)), 60 * 1000).unref();
            console.log('✅ MySQL bağlantısı kuruldu');
            break;
        } catch (err) {
            console.log(`⏳ MySQL bağlantısı bekleniyor... (${retries} deneme kaldı)`);
            retries--;
            await new Promise(r => setTimeout(r, 3000));
        }
    }
    if (!pool) { console.error('❌ MySQL bağlantısı başarısız'); process.exit(1); }
}
connectDB();

// Reservation window: 09:00 through 02:00. 00:00 and 01:00 belong to the
// same evening's booking day and each reservation is exactly one hour.
const SLOT_HOURS = [...Array.from({ length: 15 }, (_, i) => `${String(i + 9).padStart(2, '0')}:00`), '00:00', '01:00'];
const bookingMinutes = slot => {
    const value = minutes(slot);
    return value < 9 * 60 ? value + 24 * 60 : value;
};
const slotIsPast = (date, slot, now = istanbulNow()) => date < now.date || (date === now.date && bookingMinutes(slot) <= bookingMinutes(`${String(Math.floor(now.minutes / 60)).padStart(2, '0')}:${String(now.minutes % 60).padStart(2, '0')}`));
const SPORTS_FIELDS = [
    ['Halı Saha YT KAMPUS', 'Kapalı, UEFA Standartlarında profesyonel saha', 10, 4000],
    ['Halı Saha INTER HALISAHA', 'Kapalı, UEFA Standartlarında profesyonel saha', 10, 4000],
    ['Tenis Kortu YT KAMPUS', 'Akrilik zemin, gece aydınlatmalı tenis kortu', 4, 1000],
    ['Voleybol Sahası YT KAMPUS', 'Kapalı salon voleybol sahası', 12, 3000],
    ['Basketbol Sahası YT KAMPUS', 'Tam saha potalı basketbol alanı', 10, 3000],
    ['YT KAMPUS Müzik', 'Müzik stüdyosu', 10, 3000],
    ['YT KAMPUS Sanat (Resim)', 'Sanat atölyesi', 10, 3000],
    ['YT KAMPUS Dans', 'Dans okulu', 10, 3000],
    ['Padel Kortu YT KAMPUS', 'YAKINDA', 4, 3000],
    ['Havuz YT KAMPUS', 'YAKINDA', 4, 3000],
    ['Toplantı Odası YT KAMPUS', 'Sunum ekranı, hızlı internet ve konforlu oturma düzeniyle saatlik kiralanabilir toplantı odası', 12, 1000]
];
async function ensureSportsFields() {
    const [rows] = await pool.query('SELECT name FROM fields');
    const existing = new Set(rows.map(row => row.name));
    for (const [name, description, capacity, price] of SPORTS_FIELDS) {
        if (!existing.has(name)) await pool.query('INSERT INTO fields (name, description, capacity, price_per_hour) VALUES (?, ?, ?, ?)', [name, description, capacity, price]);
        else if (name === 'Toplantı Odası YT KAMPUS') await pool.query('UPDATE fields SET description = ?, capacity = ?, price_per_hour = ? WHERE name = ?', [description, capacity, price, name]);
    }
    // Aynı sanat alanının eski, genel adlı kaydı kullanıcıya gösterilmez.
    await pool.query("UPDATE fields SET is_active = 0 WHERE name = 'YT KAMPUS Sanat'");
}
async function ensurePaymentColumns() {
    const [transactionColumn] = await pool.query("SHOW COLUMNS FROM reservations LIKE 'payment_transaction_id'");
    if (!transactionColumn.length) await pool.query('ALTER TABLE reservations ADD COLUMN payment_transaction_id VARCHAR(100) NULL');
    const [paymentIdColumn] = await pool.query("SHOW COLUMNS FROM reservations LIKE 'iyzico_payment_id'");
    if (!paymentIdColumn.length) await pool.query('ALTER TABLE reservations ADD COLUMN iyzico_payment_id VARCHAR(100) NULL');
}
async function ensureReservationIndexes() {
    try {
        await pool.query('CREATE INDEX idx_reservations_field_date ON reservations (field_id, date)');
    } catch (err) {
        if (err.code !== 'ER_DUP_KEYNAME') throw err;
    }
}
async function ensurePaymentIntentsTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS payment_intents (
        id CHAR(36) PRIMARY KEY,
        user_id INT NOT NULL,
        field_id INT NOT NULL,
        date DATE NOT NULL,
        time_slot VARCHAR(20) NOT NULL,
        duration_hours INT NOT NULL,
        total_amount DECIMAL(10,2) NOT NULL,
        status ENUM('pending', 'paid', 'expired') NOT NULL DEFAULT 'pending',
        payment_transaction_id VARCHAR(100) NULL,
        iyzico_payment_id VARCHAR(100) NULL,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_payment_intents_expiry (status, expires_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (field_id) REFERENCES fields(id)
    )`);
    const [tokenColumn] = await pool.query("SHOW COLUMNS FROM payment_intents LIKE 'checkout_token'");
    if (!tokenColumn.length) await pool.query('ALTER TABLE payment_intents ADD COLUMN checkout_token VARCHAR(255) NULL');
}
async function ensureAcademyPaymentIntentsTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS academy_payment_intents (
        id CHAR(36) PRIMARY KEY,
        group_id CHAR(36) NOT NULL UNIQUE,
        user_id INT NOT NULL,
        total_amount DECIMAL(10,2) NOT NULL,
        status ENUM('pending', 'paid', 'expired') NOT NULL DEFAULT 'pending',
        checkout_token VARCHAR(255) NULL UNIQUE,
        payment_transaction_id VARCHAR(100) NULL,
        iyzico_payment_id VARCHAR(100) NULL,
        expires_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_academy_payment_expiry (status, expires_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
}
async function ensureVideoClipsTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS video_clips (
        id INT AUTO_INCREMENT PRIMARY KEY,
        file_name VARCHAR(100) NOT NULL UNIQUE,
        video_id INT NOT NULL,
        user_id INT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (video_id) REFERENCES match_videos(id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
}
async function ensureMatchVideoRetentionColumn() {
    const [createdColumn] = await pool.query("SHOW COLUMNS FROM match_videos LIKE 'created_at'");
    if (!createdColumn.length) await pool.query('ALTER TABLE match_videos ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP');
    try { await pool.query('CREATE INDEX idx_match_videos_retention ON match_videos (created_at)'); } catch (err) { if (err.code !== 'ER_DUP_KEYNAME') throw err; }
}
async function ensureFieldMediaColumn() {
    const [imageColumn] = await pool.query("SHOW COLUMNS FROM fields LIKE 'image_url'");
    if (!imageColumn.length) await pool.query('ALTER TABLE fields ADD COLUMN image_url VARCHAR(255) NULL');
}
async function ensureSeparateFieldImages() {
    const [imageColumn] = await pool.query("SHOW COLUMNS FROM fields LIKE 'homepage_image_url'");
    if (!imageColumn.length) await pool.query('ALTER TABLE fields ADD COLUMN homepage_image_url VARCHAR(255) NULL');
}
async function ensureSiteSettingsTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS site_settings (
        setting_key VARCHAR(60) PRIMARY KEY,
        setting_value VARCHAR(255) NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )`);
}
async function migrateLegacyHeroImage() {
    const key = 'migration_hero_image_v1';
    const [[completed]] = await pool.query('SELECT setting_key FROM site_settings WHERE setting_key = ?', [key]);
    if (completed) return;
    const [[legacy]] = await pool.query("SELECT setting_value FROM site_settings WHERE setting_key = 'hero_logo'");
    if (legacy?.setting_value) {
        await pool.query("INSERT INTO site_settings (setting_key, setting_value) VALUES ('hero_image', ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)", [legacy.setting_value]);
    }
    await pool.query('INSERT INTO site_settings (setting_key, setting_value) VALUES (?, ?)', [key, 'completed']);
}
async function restoreInterCatalogBallOnce() {
    const key = 'migration_inter_catalog_ball_v1';
    const [[completed]] = await pool.query('SELECT setting_key FROM site_settings WHERE setting_key = ?', [key]);
    if (completed) return;
    // INTER saha için kullanıcı kartındaki önceki top görseli, görsel seçilmediğinde kullanılan varsayılandır.
    await pool.query("UPDATE fields SET image_url = NULL WHERE name = 'Halı Saha INTER HALISAHA'");
    await pool.query('INSERT INTO site_settings (setting_key, setting_value) VALUES (?, ?)', [key, 'completed']);
}
async function ensureNotificationsTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS notifications (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id INT NOT NULL,
        title VARCHAR(160) NOT NULL,
        message VARCHAR(500) NOT NULL,
        type ENUM('reservation', 'payment', 'video', 'system') NOT NULL DEFAULT 'system',
        is_read BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_notifications_user_read (user_id, is_read, created_at),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
}
async function ensureReservationCreatorColumn() {
    const [column] = await pool.query("SHOW COLUMNS FROM reservations LIKE 'created_by'");
    if (!column.length) await pool.query('ALTER TABLE reservations ADD COLUMN created_by INT NULL');
}
async function ensureAuditLogTable() {
    await pool.query(`CREATE TABLE IF NOT EXISTS admin_activity_logs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        actor_user_id INT NOT NULL,
        action VARCHAR(80) NOT NULL,
        entity_type VARCHAR(50) NOT NULL,
        entity_id INT NULL,
        details VARCHAR(1000) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_activity_created (created_at),
        INDEX idx_activity_actor (actor_user_id),
        FOREIGN KEY (actor_user_id) REFERENCES users(id) ON DELETE CASCADE
    )`);
}
async function logAdminActivity(actorUserId, action, entityType, entityId = null, details = null) {
    if (!Number.isInteger(Number(actorUserId))) return;
    await pool.query('INSERT INTO admin_activity_logs (actor_user_id, action, entity_type, entity_id, details) VALUES (?, ?, ?, ?, ?)', [Number(actorUserId), String(action).slice(0, 80), String(entityType).slice(0, 50), entityId ? Number(entityId) : null, details ? String(details).slice(0, 1000) : null]);
}
async function createNotification(userId, title, message, type = 'system') {
    if (!Number.isInteger(Number(userId))) return;
    await pool.query('INSERT INTO notifications (user_id, title, message, type) VALUES (?, ?, ?, ?)', [Number(userId), String(title).slice(0, 160), String(message).slice(0, 500), type]);
}
async function notifyAdmins(title, message, type = 'system') {
    const [admins] = await pool.query("SELECT id FROM users WHERE role = 'admin' AND is_active = 1");
    await Promise.all(admins.map(admin => createNotification(admin.id, title, message, type)));
}
async function unlinkIfExists(filePath) {
    try { await fsModule.promises.unlink(filePath); } catch (err) { if (err.code !== 'ENOENT') throw err; }
}
async function isValidImageFile(filePath, extension) {
    const header = await fsModule.promises.open(filePath, 'r').then(async file => {
        try { const buffer = Buffer.alloc(16); await file.read(buffer, 0, buffer.length, 0); return buffer; } finally { await file.close(); }
    }).catch(() => null);
    if (!header) return false;
    if (extension === 'jpg') return header[0] === 0xff && header[1] === 0xd8 && header[2] === 0xff;
    if (extension === 'png') return header.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    if (extension === 'webp') return header.subarray(0, 4).toString('ascii') === 'RIFF' && header.subarray(8, 12).toString('ascii') === 'WEBP';
    return false;
}
async function cleanupExpiredMedia() {
    if (!pool) return;
    const uploadsDir = path.resolve(__dirname, 'uploads');
    const [expiredVideos] = await pool.query("SELECT id, video_url FROM match_videos WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");
    for (const video of expiredVideos) {
        const [clips] = await pool.query('SELECT file_name FROM video_clips WHERE video_id = ?', [video.id]);
        await Promise.all([unlinkIfExists(path.join(uploadsDir, path.basename(video.video_url))), ...clips.map(clip => unlinkIfExists(path.join(uploadsDir, path.basename(clip.file_name)) ))]);
        await pool.query('DELETE FROM match_videos WHERE id = ?', [video.id]);
    }
    const [expiredClips] = await pool.query("SELECT file_name FROM video_clips WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");
    for (const clip of expiredClips) await unlinkIfExists(path.join(uploadsDir, path.basename(clip.file_name)));
    if (expiredClips.length) await pool.query("DELETE FROM video_clips WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)");
    if (expiredVideos.length || expiredClips.length) console.log(`🧹 ${expiredVideos.length} video ve ${expiredClips.length} kesit temizlendi`);
}
async function cleanupExpiredPayments() {
    if (!pool) return;
    await pool.query("UPDATE payment_intents SET status = 'expired' WHERE status = 'pending' AND expires_at < NOW()");
    const [expiredAcademy] = await pool.query("SELECT id, group_id, user_id FROM academy_payment_intents WHERE status = 'pending' AND expires_at < NOW()");
    for (const intent of expiredAcademy) {
        const connection = await pool.getConnection();
        try {
            await connection.beginTransaction();
            const [[current]] = await connection.query("SELECT status FROM academy_payment_intents WHERE id = ? FOR UPDATE", [intent.id]);
            if (current?.status === 'pending') {
                await connection.query("UPDATE academy_payment_intents SET status = 'expired' WHERE id = ?", [intent.id]);
                await connection.query("DELETE FROM reservations WHERE user_id = ? AND status = 'pending' AND notes LIKE ?", [intent.user_id, `%group: ${intent.group_id}%`]);
            }
            await connection.commit();
        } catch (error) { await connection.rollback(); throw error; } finally { connection.release(); }
    }
}
async function removeNationalIdentityColumn() {
    const [columns] = await pool.query("SHOW COLUMNS FROM users LIKE 'tc_kimlik'");
    if (columns.length) await pool.query('ALTER TABLE users DROP COLUMN tc_kimlik');
}
const validStatuses = new Set(['pending', 'confirmed', 'cancelled', 'completed']);
const validPaymentStatuses = new Set(['unpaid', 'paid']);
const academyPackagePrices = Object.freeze({
    'Özel Ders': 16000,
    '2 Kişilik Grup': 12000,
    '3 Kişilik Grup': 10000,
    'Grup Eğitimi': 8000,
    'Çocuk Akademi': 8000,
    'Dans Özel Ders (Haftada 2)': 16000,
    'Dans Özel Ders (Haftada 3)': 24000,
    'Dans Grup (Haftada 2)': 8000,
    'Dans Grup (Haftada 3)': 12000,
    'Resim Özel Ders': 15000,
    'Resim Grup Dersleri': 8000
});
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;
const normalizeEmail = value => String(value || '').trim().toLowerCase();
const toDateString = value => new Date(value).toISOString().slice(0, 10);
const minutes = slot => { const [hour, minute] = String(slot).split(':').map(Number); return hour * 60 + minute; };
const escapeLike = value => String(value).replace(/[\\%_]/g, '\\$&');
function istanbulNow() {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Istanbul', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(new Date());
    const value = Object.fromEntries(parts.filter(part => part.type !== 'literal').map(part => [part.type, part.value]));
    return { date: `${value.year}-${value.month}-${value.day}`, minutes: Number(value.hour) * 60 + Number(value.minute) };
}
function isWithinCancellationLock(reservation) {
    const startsAt = new Date(`${toDateString(reservation.date)}T${reservation.time_slot}:00+03:00`);
    return startsAt.getTime() - Date.now() < 24 * 60 * 60 * 1000;
}

// ─── Middleware: JWT Auth ──────────────────────────────────────────────────────
const auth = async (req, res, next) => {
    const token = req.headers.authorization?.split(' ')[1] || cookieValue(req, AUTH_COOKIE);
    if (!token) return res.status(401).json({ error: 'Token gerekli' });
    try {
        const claims = jwt.verify(token, JWT_SECRET);
        const [[user]] = await pool.query('SELECT id, email, role, full_name, avatar_color, is_active FROM users WHERE id = ?', [claims.id]);
        if (!user || !user.is_active) return res.status(401).json({ error: 'Oturum geçersiz veya kullanıcı pasif' });
        req.user = user;
        next();
    } catch { res.status(401).json({ error: 'Geçersiz token' }); }
};

const adminOnly = (req, res, next) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Admin yetkisi gerekli' });
    next();
};

// ─── AUTH ROUTES ──────────────────────────────────────────────────────────────
app.post('/api/auth/register', authRateLimit, async (req, res) => {
    const full_name = String(req.body.full_name || '').trim();
    const email = normalizeEmail(req.body.email);
    const phone = String(req.body.phone || '').trim();
    const password = String(req.body.password || '');
    
    // New fields
    const birth_date = req.body.birth_date ? toDateString(req.body.birth_date) : null;
    const birth_place = String(req.body.birth_place || '').trim();
    const parent_name = String(req.body.parent_name || '').trim();
    const parent_phone = String(req.body.parent_phone || '').trim();
    const city = String(req.body.city || '').trim();
    const district = String(req.body.district || '').trim();
    const address = String(req.body.address || '').trim();
    const reference_source = String(req.body.reference_source || '').trim();
    const blood_type = String(req.body.blood_type || '').trim();
    const health_conditions = String(req.body.health_conditions || '').trim();
    const kvkk_approved = req.body.kvkk_approved === true;
    const contract_approved = req.body.contract_approved === true;

    if (full_name.length < 2 || full_name.length > 100 || !emailPattern.test(email) || password.length < 8) {
        return res.status(400).json({ error: 'Ad soyad, geçerli e-posta ve en az 8 karakter şifre gereklidir' });
    }
    if (!kvkk_approved || !contract_approved) {
        return res.status(400).json({ error: 'KVKK ve Üyelik Sözleşmesini onaylamanız gereklidir' });
    }
    
    try {
        const [existing] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
        if (existing.length > 0) return res.status(409).json({ error: 'Bu e-posta zaten kayıtlı' });
        
        const hash = await bcrypt.hash(password, 12);
        const colors = ['#4ade80', '#60a5fa', '#f472b6', '#fb923c', '#a78bfa'];
        const color = colors[Math.floor(Math.random() * colors.length)];
        
        const [result] = await pool.query(
            `INSERT INTO users 
            (full_name, email, phone, password_hash, role, avatar_color, birth_date, birth_place, parent_name, parent_phone, city, district, address, reference_source, blood_type, health_conditions, kvkk_approved, contract_approved) 
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [full_name, email, phone, hash, 'customer', color, birth_date, birth_place, parent_name, parent_phone, city, district, address, reference_source, blood_type, health_conditions, kvkk_approved, contract_approved]
        );
        
        const token = jwt.sign({ id: result.insertId, email, role: 'customer', full_name, avatar_color: color }, JWT_SECRET, { expiresIn: '2h' });
        issueSession(res, token);
        res.json({ success: true, user: { id: result.insertId, full_name, email, role: 'customer', avatar_color: color }, ...(isNativeMobileClient(req) ? { token } : {}) });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/login', authRateLimit, async (req, res) => {
    const loginId = normalizeEmail(req.body.email);
    const password = String(req.body.password || '');
    if (!loginId || !password) return res.status(400).json({ error: 'E-posta/kullanıcı adı ve şifre gerekli' });
    try {
        const [rows] = await pool.query(
            'SELECT * FROM users WHERE (email = ? OR legacy_username = ?) AND is_active = 1',
            [loginId, loginId]
        );
        if (rows.length === 0) return res.status(401).json({ error: 'Hatalı e-posta veya şifre' });
        const user = rows[0];
        const bcryptHash = /^\$2[aby]\$\d{2}\$/.test(user.password_hash);
        const provided = Buffer.from(password);
        const stored = Buffer.from(user.password_hash);
        const legacyMatch = !bcryptHash && provided.length === stored.length && crypto.timingSafeEqual(provided, stored);
        const match = bcryptHash ? await bcrypt.compare(password, user.password_hash) : legacyMatch;
        if (!match) return res.status(401).json({ error: 'Hatalı e-posta veya şifre' });
        if (!bcryptHash) {
            const upgradedHash = await bcrypt.hash(password, 12);
            await pool.query('UPDATE users SET password_hash = ?, password = NULL WHERE id = ?', [upgradedHash, user.id]);
        }
        const token = jwt.sign(
            { id: user.id, email: user.email, role: user.role, full_name: user.full_name, avatar_color: user.avatar_color },
            JWT_SECRET, { expiresIn: '2h' }
        );
        issueSession(res, token);
        res.json({ success: true, user: { id: user.id, full_name: user.full_name, email: user.email, phone: user.phone, role: user.role, avatar_color: user.avatar_color }, ...(isNativeMobileClient(req) ? { token } : {}) });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.post('/api/auth/logout', (req, res) => {
    res.clearCookie(AUTH_COOKIE, { httpOnly: true, sameSite: 'strict', secure: !isLocalPaymentHost, path: '/' });
    res.status(204).end();
});

app.get('/api/auth/me', auth, async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT id, full_name, email, phone, role, avatar_color, created_at FROM users WHERE id = ?', [req.user.id]);
        if (rows.length === 0) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        res.json(rows[0]);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.patch('/api/auth/me', auth, async (req, res) => {
    const full_name = String(req.body.full_name || '').trim();
    const phone = String(req.body.phone || '').trim();
    const email = normalizeEmail(req.body.email);
    if (full_name.length < 2 || full_name.length > 100 || phone.length > 20 || !emailPattern.test(email)) return res.status(400).json({ error: 'Profil bilgilerini kontrol edin' });
    try {
        const [[existing]] = await pool.query('SELECT id FROM users WHERE email = ? AND id <> ?', [email, req.user.id]);
        if (existing) return res.status(409).json({ error: 'Bu e-posta başka bir hesapta kullanılıyor' });
        await pool.query('UPDATE users SET full_name = ?, email = ?, phone = ? WHERE id = ?', [full_name, email, phone, req.user.id]);
        res.json({ success: true, user: { ...req.user, full_name, email, phone } });
    } catch (err) { res.status(500).json({ error: 'Profil güncellenemedi' }); }
});

app.patch('/api/auth/password', auth, async (req, res) => {
    const current_password = String(req.body.current_password || '');
    const password = String(req.body.password || '');
    if (password.length < 8) return res.status(400).json({ error: 'Yeni şifre en az 8 karakter olmalıdır' });
    try {
        const [[user]] = await pool.query('SELECT password_hash FROM users WHERE id = ?', [req.user.id]);
        if (!user || !await bcrypt.compare(current_password, user.password_hash)) return res.status(400).json({ error: 'Mevcut şifre doğru değil' });
        await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [await bcrypt.hash(password, 12), req.user.id]);
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: 'Şifre güncellenemedi' }); }
});

// ─── FIELDS ROUTES ────────────────────────────────────────────────────────────
app.get('/api/fields', async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT * FROM fields WHERE is_active = 1');
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});
app.get('/api/site-images', async (req, res) => {
    const [rows] = await pool.query('SELECT setting_key, setting_value FROM site_settings');
    res.json(Object.fromEntries(rows.map(row => [row.setting_key, row.setting_value])));
});

// ─── RESERVATION ROUTES ───────────────────────────────────────────────────────
// Get available slots for a date
app.get('/api/slots', async (req, res) => {
    const { date, field_id = 1 } = req.query;
    if (!datePattern.test(date) || !Number.isInteger(Number(field_id))) return res.status(400).json({ error: 'Geçerli tarih ve saha seçin' });
    try {
        const [[field]] = await pool.query('SELECT id FROM fields WHERE id = ? AND is_active = 1', [field_id]);
        if (!field) return res.status(404).json({ error: 'Saha bulunamadı' });
        const [rows] = await pool.query(
            "SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')",
            [date, field_id]
        );
        const bookedSlots = [...new Set(rows.flatMap(r => { const at = SLOT_HOURS.indexOf(r.time_slot); return at < 0 ? [] : SLOT_HOURS.slice(at, at + Number(r.duration_hours)); }))];
        res.json({ slots: SLOT_HOURS, bookedSlots });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Seven-day occupancy summary for one sports area. Deliberately returns only
// occupied hours, never reservation owner details.
app.get('/api/slots/week', async (req, res) => {
    const fieldId = Number(req.query.field_id);
    if (!Number.isInteger(fieldId)) return res.status(400).json({ error: 'Geçerli saha seçin' });
    const startDate = String(req.query.start_date || istanbulNow().date);
    if (!datePattern.test(startDate)) return res.status(400).json({ error: 'Geçerli hafta başlangıcı seçin' });
    try {
        const [rows] = await pool.query(
            "SELECT date, time_slot, duration_hours FROM reservations WHERE field_id = ? AND date BETWEEN ? AND DATE_ADD(?, INTERVAL 6 DAY) AND status IN ('pending', 'confirmed')",
            [fieldId, startDate, startDate]
        );
        res.json({ reservations: rows });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Book a reservation

// Academy Subscription Endpoint
app.post('/api/reservations/academy', auth, async (req, res) => {
    const { field_id, package_name, schedule, duration_hours = 1 } = req.body;
    // schedule is array like: [{day: 1, time: '18:00'}, {day: 3, time: '19:00'}]
    const fieldId = Number(field_id);
    const duration = Number(duration_hours);
    const totalAmount = academyPackagePrices[package_name];
    if (!Number.isInteger(fieldId) || !totalAmount || !Array.isArray(schedule) || !Number.isInteger(duration) || duration < 1 || duration > 3) {
       return res.status(400).json({ error: 'Geçersiz akademi paket bilgileri.' });
    }
    if (schedule.some(item => !Number.isInteger(Number(item.day)) || Number(item.day) < 1 || Number(item.day) > 7 || !SLOT_HOURS.includes(item.time))) {
        return res.status(400).json({ error: 'Program bilgileri geçerli değil.' });
    }

    try {
        const [[field]] = await pool.query('SELECT id, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [fieldId]);
        if (!field) return res.status(404).json({ error: 'Saha bulunamadı veya kullanıma kapalı' });

        const reservationsToCreate = [];
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        if (schedule.length === 0) {
            // It's a group class where schedule is decided by facility.
            // Just create 1 dummy record as the subscription tracking record.
            const yyyy = today.getFullYear();
            const mm = String(today.getMonth() + 1).padStart(2, '0');
            const dd = String(today.getDate()).padStart(2, '0');
            reservationsToCreate.push({
                date: `${yyyy}-${mm}-${dd}`,
                time_slot: '09:00', // dummy
                // Grup eğitiminde tesis saati sonradan belirler. Bu kayıt alanı bloke etmez.
                duration: 0
            });
        }


        for (let week = 0; week < 4; week++) {
            for (const item of schedule) {
                const targetDay = Number(item.day); // 1-7
                const targetTime = item.time;
                
                // Find next matching date
                const date = new Date(today);
                let currentDay = date.getDay(); // 0 is Sunday, 1 is Monday
                if (currentDay === 0) currentDay = 7;
                
                let daysToAdd = targetDay - currentDay;
                if (daysToAdd < 0 || (daysToAdd === 0 && week > 0)) {
                   daysToAdd += 7; // Go to next week if day already passed this week
                }
                daysToAdd += (week * 7);
                
                date.setDate(date.getDate() + daysToAdd);
                
                const yyyy = date.getFullYear();
                const mm = String(date.getMonth() + 1).padStart(2, '0');
                const dd = String(date.getDate()).padStart(2, '0');
                const dateStr = `${yyyy}-${mm}-${dd}`;
                
                reservationsToCreate.push({
                    date: dateStr,
                    time_slot: targetTime,
                    duration
                });
            }
        }

        // Check if ANY of the computed dates are booked (except dummy rows)
        if (schedule.length > 0) {
            for (const reqRes of reservationsToCreate) {
                const [existing] = await pool.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')", [reqRes.date, fieldId]);
                const requestedStart = minutes(reqRes.time_slot);
                const requestedEnd = requestedStart + reqRes.duration * 60;
                
                if (existing.some(r => requestedStart < minutes(r.time_slot) + Number(r.duration_hours) * 60 && requestedEnd > minutes(r.time_slot))) {
                    return res.status(409).json({ error: `${reqRes.date} ${reqRes.time_slot} tarihi maalesef dolu. Lütfen farklı bir gün/saat programı seçin.` });
                }
            }
        }

        // Create all reservations
        // Let's divide package price by total sessions to distribute it, or just mark total_price = 0 and handle payment via package.
        // For simplicity, we just mark total_price as 0 and notes as 'Academy Package: ' + package_name
        // Tahmin edilebilir zaman damgası yerine sağlayıcı ile eşleştirilecek tekil grup kimliği.
        const groupId = crypto.randomUUID();
        const amountPerRecord = totalAmount / reservationsToCreate.length;
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, fieldId, reqRes.date, reqRes.time_slot, reqRes.duration, amountPerRecord, `Abonelik: ${package_name} | group: ${groupId}`]
            );
        }
        await pool.query(
            'INSERT INTO academy_payment_intents (id, group_id, user_id, total_amount, expires_at) VALUES (?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE))',
            [crypto.randomUUID(), groupId, req.user.id, totalAmount]
        );

        res.json({ success: true, message: 'Abonelik rezervasyonları oluşturuldu.', group_id: groupId, total_sessions: reservationsToCreate.length });

    } catch (e) {
        console.error('Academy reservation error:', e);
        res.status(500).json({ error: 'Sunucu hatası' });
    }
});

app.post('/api/reservations', auth, async (req, res) => {
    const { date, time_slot, field_id = 1, duration_hours = 1 } = req.body;
    const notes = String(req.body.notes || '').trim().slice(0, 1000);
    const duration = Number(duration_hours);
    const fieldId = Number(field_id);
    const isOnlinePayment = req.body.payment_method === 'online';
    if (isOnlinePayment) return res.status(400).json({ error: 'Online ödemeler ödeme niyeti akışıyla başlatılmalıdır' });
    if (!datePattern.test(date) || !SLOT_HOURS.includes(time_slot) || !Number.isInteger(fieldId) || duration !== 1) return res.status(400).json({ error: 'Rezervasyonlar yalnızca 09:00–02:00 arasında ve 1 saatlik yapılabilir' });
    const now = istanbulNow();
    if (slotIsPast(date, time_slot, now)) return res.status(400).json({ error: 'Geçmiş saatler için rezervasyon yapılamaz' });
    if (!SLOT_HOURS.includes(SLOT_HOURS[SLOT_HOURS.indexOf(time_slot) + duration - 1])) return res.status(400).json({ error: 'Seçilen süre tesisin çalışma saatlerini aşıyor' });
    const connection = await pool.getConnection();
    try {
        const lockName = `reservation:${fieldId}:${date}`;
        const [[lock]] = await connection.query('SELECT GET_LOCK(?, 5) AS acquired', [lockName]);
        if (!lock.acquired) return res.status(409).json({ error: 'Bu saha için işlem sürüyor, lütfen tekrar deneyin' });
        const [[field]] = await connection.query('SELECT id, name, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [fieldId]);
        if (!field) return res.status(404).json({ error: 'Saha bulunamadı veya kullanıma kapalı' });
        if (isOnlinePayment) {
            const [[ownPendingReservation]] = await connection.query(
                "SELECT id, total_amount FROM reservations WHERE user_id = ? AND field_id = ? AND date = ? AND time_slot = ? AND duration_hours = ? AND status = 'pending' AND payment_status = 'unpaid' LIMIT 1",
                [req.user.id, fieldId, date, time_slot, duration]
            );
            if (ownPendingReservation) {
                return res.json({ success: true, reservation_id: ownPendingReservation.id, total_amount: Number(ownPendingReservation.total_amount), reused_pending_reservation: true });
            }
        }
        const [existing] = await connection.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed') FOR UPDATE", [date, fieldId]);
        if (existing.some(r => r.time_slot === time_slot)) return res.status(409).json({ error: 'Seçtiğiniz saat dolu' });
        const total = Number(field.price_per_hour) * duration;
        const [result] = await connection.query(
            "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes, payment_status, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [req.user.id, fieldId, date, time_slot, duration, total, isOnlinePayment ? 'pending' : 'confirmed', notes, req.body.payment_method === 'test_card' ? 'paid' : 'unpaid', isOnlinePayment ? 'online' : (req.body.payment_method === 'test_card' ? 'test_card' : 'on_site')]
        );
        await createNotification(req.user.id, 'Rezervasyonunuz oluşturuldu', `${field.name} · ${date} · ${time_slot}. Rezervasyonlar iptal edilemez.`, 'reservation');
        await notifyAdmins('Yeni rezervasyon', `${req.user.full_name} · ${field.name} · ${date} · ${time_slot}`, 'reservation');
        res.json({ success: true, reservation_id: result.insertId, total_amount: total });
    } catch (err) {
        console.error('Reservation error:', err);
        res.status(500).json({ error: 'Rezervasyon oluşturulamadı' });
    } finally {
        try { await connection.query('SELECT RELEASE_LOCK(?)', [`reservation:${fieldId}:${date}`]); } catch {}
        connection.release();
    }
});

// Get user's own reservations

// Recurring slots availability for 4 weeks
app.get('/api/slots/recurring', async (req, res) => {
    const { field_id, duration_hours = 1 } = req.query;
    if (!field_id) return res.status(400).json({ error: 'field_id gerekli' });

    try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        // Fetch all upcoming reservations for this field for the next 30 days
        const endDate = new Date(today);
        endDate.setDate(endDate.getDate() + 30);
        
        const yyyy = endDate.getFullYear();
        const mm = String(endDate.getMonth() + 1).padStart(2, '0');
        const dd = String(endDate.getDate()).padStart(2, '0');
        const endStr = `${yyyy}-${mm}-${dd}`;

        const [reservations] = await pool.query(
            "SELECT date, time_slot, duration_hours FROM reservations WHERE field_id = ? AND date >= CURRENT_DATE AND date <= ? AND status IN ('pending', 'confirmed')",
            [field_id, endStr]
        );

        // We want to return a 7-day grid (Mon-Sun), from 09:00 to 23:00.
        // A slot is "available" if it is free on ALL 4 occurrences of that day in the next 28 days.
        const grid = {};
        for(let d=1; d<=7; d++) grid[d] = {}; // 1: Monday, 7: Sunday

        const SLOT_HOURS = [...Array.from({length: 15}, (_,i) => String(i+9).padStart(2, '0') + ':00'), '00:00', '01:00'];
        const duration = Number(duration_hours);

        const minutes = (time) => {
            const [h, m] = time.split(':').map(Number);
            return h * 60 + (m || 0);
        };

        for (let d = 1; d <= 7; d++) {
            for (const time of SLOT_HOURS) {
                const requestedStart = minutes(time);
                const requestedEnd = requestedStart + duration * 60;
                
                // If it goes past 24:00, not available (or if 24:00 is not in SLOT_HOURS)
                if (requestedEnd > 24 * 60) {
                   grid[d][time] = false;
                   continue;
                }

                let isAvailable = true;

                // Check all 4 weeks for this day
                for (let week = 0; week < 4; week++) {
                    const checkDate = new Date(today);
                    let currentDay = checkDate.getDay();
                    if (currentDay === 0) currentDay = 7;
                    let daysToAdd = d - currentDay;
                    if (daysToAdd < 0 || (daysToAdd === 0 && week > 0)) daysToAdd += 7;
                    daysToAdd += (week * 7);
                    
                    checkDate.setDate(checkDate.getDate() + daysToAdd);
                    const c_yyyy = checkDate.getFullYear();
                    const c_mm = String(checkDate.getMonth() + 1).padStart(2, '0');
                    const c_dd = String(checkDate.getDate()).padStart(2, '0');
                    const cStr = `${c_yyyy}-${c_mm}-${c_dd}`;

                    // Any overlap?
                    const conflict = reservations.some(r => {
                        // Date must match exactly
                        if (r.date !== cStr) return false;
                        const rStart = minutes(r.time_slot);
                        const rEnd = rStart + Number(r.duration_hours) * 60;
                        return (requestedStart < rEnd && requestedEnd > rStart);
                    });

                    if (conflict) {
                        isAvailable = false;
                        break;
                    }
                }
                
                grid[d][time] = isAvailable;
            }
        }

        res.json({ success: true, availability: grid });

    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Sunucu hatası' });
    }
});

app.get('/api/reservations/my', auth, async (req, res) => {
    try {
        const [rows] = await pool.query(
            'SELECT r.*, f.name as field_name FROM reservations r JOIN fields f ON r.field_id = f.id WHERE r.user_id = ? ORDER BY r.date DESC, r.time_slot DESC',
            [req.user.id]
        );
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Reservations are final once created. Only administrator-created availability
// blocks can be ended through their dedicated recurring-block endpoint.
app.patch('/api/reservations/:id/cancel', auth, (req, res) => {
    res.status(403).json({ error: 'Rezervasyon iptali ve iade işlemi kapalıdır. Oluşturulan rezervasyonlar değiştirilemez.' });
});

// ─── ADMIN ROUTES ─────────────────────────────────────────────────────────────
// Dashboard stats
app.get('/api/admin/stats', auth, adminOnly, async (req, res) => {
    try {
        const [[totalRes]] = await pool.query("SELECT COUNT(*) as count FROM reservations WHERE status != 'cancelled'");
        const [[todayRes]] = await pool.query("SELECT COUNT(*) as count FROM reservations WHERE date = CURDATE() AND status != 'cancelled'");
        const [[revenue]] = await pool.query("SELECT COALESCE(SUM(total_amount), 0) as total FROM reservations WHERE payment_status = 'paid'");
        const [[totalUsers]] = await pool.query("SELECT COUNT(*) as count FROM users WHERE role = 'customer'");
        res.json({
            total_reservations: totalRes.count,
            today_reservations: todayRes.count,
            total_revenue: revenue.total,
            total_customers: totalUsers.count
        });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Get all reservations
app.get('/api/admin/reservations', auth, adminOnly, async (req, res) => {
    try {
        const { date, status } = req.query;
        let query = 'SELECT r.*, u.full_name, u.email, u.phone, u.avatar_color, f.name as field_name, creator.full_name AS created_by_name FROM reservations r LEFT JOIN users u ON r.user_id = u.id LEFT JOIN users creator ON r.created_by = creator.id LEFT JOIN fields f ON r.field_id = f.id';
        const params = [];
        const conditions = [];
        if (date) { conditions.push('r.date = ?'); params.push(date); }
        if (status) { conditions.push('r.status = ?'); params.push(status); }
        if (conditions.length) query += ' WHERE ' + conditions.join(' AND ');
        query += ' ORDER BY r.date DESC, r.time_slot DESC';
        const [rows] = await pool.query(query, params);
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Admin-created block or recurring subscription. These are always collected on-site.
app.post('/api/admin/reservations/manual', auth, adminOnly, async (req, res) => {
    const fieldId = Number(req.body.field_id);
    const selectedUserId = req.body.user_id ? Number(req.body.user_id) : req.user.id;
    const date = toDateString(req.body.date);
    const timeSlot = String(req.body.time_slot || '');
    const recurrence = String(req.body.recurrence || 'once');
    const repetitions = recurrence === 'monthly' ? 4 : recurrence === 'yearly' ? 52 : recurrence === 'once' ? 1 : 0;
    if (!Number.isInteger(fieldId) || !Number.isInteger(selectedUserId) || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !SLOT_HOURS.includes(timeSlot) || !repetitions) {
        return res.status(400).json({ error: 'Rezervasyon bilgileri geçersiz' });
    }
    if (slotIsPast(date, timeSlot)) return res.status(400).json({ error: 'Geçmiş bir saat için kayıt oluşturulamaz' });
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();
        const [[field]] = await connection.query('SELECT id, name, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [fieldId]);
        const [[member]] = await connection.query('SELECT id, full_name FROM users WHERE id = ? AND is_active = 1', [selectedUserId]);
        if (!field || !member) throw new Error('Saha veya kullanıcı bulunamadı');
        const start = new Date(`${date}T12:00:00Z`);
        const dates = Array.from({ length: repetitions }, (_, index) => {
            const next = new Date(start); next.setUTCDate(start.getUTCDate() + index * 7); return next.toISOString().slice(0, 10);
        });
        const placeholders = dates.map(() => '?').join(',');
        const [conflicts] = await connection.query(`SELECT date FROM reservations WHERE field_id = ? AND time_slot = ? AND date IN (${placeholders}) AND status IN ('pending','confirmed') FOR UPDATE`, [fieldId, timeSlot, ...dates]);
        if (conflicts.length) throw new Error(`${conflicts.map(row => row.date.toISOString().slice(0,10)).join(', ')} tarihinde seçili saat dolu`);
        const isBlock = !req.body.user_id;
        const seriesId = repetitions > 1 ? crypto.randomUUID() : null;
        const note = `${isBlock ? 'Yönetici blokajı' : `Yönetici aboneliği: ${recurrence === 'yearly' ? 'Yıllık' : recurrence === 'monthly' ? 'Aylık' : 'Tek seferlik'}`}${seriesId ? ` | series:${seriesId}` : ''}`;
        const createdReservationIds = [];
        for (const reservationDate of dates) {
            const [result] = await connection.query("INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes, payment_status, payment_method, created_by) VALUES (?, ?, ?, ?, 1, ?, 'confirmed', ?, 'unpaid', 'on_site', ?)", [selectedUserId, fieldId, reservationDate, timeSlot, field.price_per_hour, note, req.user.id]);
            createdReservationIds.push(result.insertId);
        }
        await connection.commit();
        await logAdminActivity(req.user.id, isBlock ? 'Saat blokajı oluşturdu' : 'Rezervasyon oluşturdu', 'reservation', createdReservationIds[0], `${member.full_name} · ${field.name} · ${date} · ${timeSlot}${repetitions > 1 ? ` · ${dates.length} haftalık kayıt` : ''}`);
        if (!isBlock) await createNotification(selectedUserId, 'Rezervasyonunuz tanımlandı', `${field.name} · ${date} · ${timeSlot}${repetitions > 1 ? ` · ${dates.length} haftalık abonelik` : ''}. Rezervasyonlar iptal edilemez.`, 'reservation');
        res.status(201).json({ success: true, created: dates.length, payment_method: 'on_site' });
    } catch (err) {
        await connection.rollback();
        res.status(409).json({ error: err.message || 'Rezervasyon oluşturulamadı' });
    } finally { connection.release(); }
});

// End a recurring manual block/subscription from its selected occurrence onward.
app.delete('/api/admin/reservations/recurring/:id', auth, adminOnly, async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ error: 'Geçersiz rezervasyon' });
    try {
        const [[reservation]] = await pool.query('SELECT date, notes, field_id, user_id, time_slot FROM reservations WHERE id = ?', [id]);
        const series = String(reservation?.notes || '').match(/(?:^|\s)series:([0-9a-f-]{36})(?:\s|$)/i)?.[1];
        if (!reservation || !String(reservation.notes || '').startsWith('Yönetici')) return res.status(400).json({ error: 'Bu kayıt yönetici blokajı değil' });
        const query = series
            ? "UPDATE reservations SET status = 'cancelled', notes = CONCAT(COALESCE(notes, ''), ' | yönetici tarafından sonlandırıldı') WHERE notes LIKE ? AND date >= ? AND status IN ('pending','confirmed')"
            : "UPDATE reservations SET status = 'cancelled', notes = CONCAT(COALESCE(notes, ''), ' | yönetici tarafından sonlandırıldı') WHERE field_id = ? AND user_id = ? AND time_slot = ? AND notes = ? AND date >= ? AND status IN ('pending','confirmed')";
        const params = series ? [`%series:${series}%`, reservation.date] : [reservation.field_id, reservation.user_id, reservation.time_slot, reservation.notes, reservation.date];
        const [result] = await pool.query(query, params);
        await logAdminActivity(req.user.id, 'Tekrarlayan rezervasyonu sonlandırdı', 'reservation', id, `${result.affectedRows} kayıt sonlandırıldı`);
        res.json({ success: true, cancelled: result.affectedRows });
    } catch { res.status(500).json({ error: 'Tekrarlayan kayıt sonlandırılamadı' }); }
});

// Update reservation status (admin)
app.patch('/api/admin/reservations/:id', auth, adminOnly, async (req, res) => {
    const { status, payment_status } = req.body;
    try {
        if (status === 'cancelled' || ['refunded', 'partially_refunded'].includes(payment_status)) {
            return res.status(403).json({ error: 'Rezervasyon iptal ve iade işlemleri kapalıdır.' });
        }
        const updates = [];
        const params = [];
        if (status && validStatuses.has(status)) { updates.push('status = ?'); params.push(status); }
        else if (status) return res.status(400).json({ error: 'Geçersiz rezervasyon durumu' });
        if (payment_status && validPaymentStatuses.has(payment_status)) { updates.push('payment_status = ?'); params.push(payment_status); }
        else if (payment_status) return res.status(400).json({ error: 'Geçersiz ödeme durumu' });
        if (!updates.length) return res.status(400).json({ error: 'Güncellenecek alan yok' });
        params.push(req.params.id);
        const [result] = await pool.query(`UPDATE reservations SET ${updates.join(', ')} WHERE id = ?`, params);
        if (!result.affectedRows) return res.status(404).json({ error: 'Rezervasyon bulunamadı' });
        await logAdminActivity(req.user.id, 'Rezervasyonu güncelledi', 'reservation', req.params.id, updates.join(', '));
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Customer reservations are immutable. Availability blocks have their own endpoint.
app.delete('/api/admin/reservations/:id', auth, adminOnly, (req, res) => {
    res.status(403).json({ error: 'Rezervasyon kayıtları silinemez veya iptal edilemez.' });
});

app.get('/api/admin/fields', auth, adminOnly, async (req, res) => {
    const [fields] = await pool.query('SELECT id, name, description, capacity, price_per_hour, is_active, image_url, homepage_image_url FROM fields WHERE is_active = 1 ORDER BY id');
    res.json({ success: true, fields });
});
app.patch('/api/admin/fields/:id', auth, adminOnly, async (req, res) => {
    const id = Number(req.params.id);
    const price = Number(req.body.price_per_hour);
    if (!Number.isInteger(id) || !Number.isFinite(price) || price < 0 || price > 1000000) return res.status(400).json({ error: 'Saha bilgileri geçersiz' });
    const [result] = await pool.query('UPDATE fields SET price_per_hour = ? WHERE id = ? AND is_active = 1', [price, id]);
    if (!result.affectedRows) return res.status(404).json({ error: 'Saha bulunamadı' });
    await logAdminActivity(req.user.id, 'Saha ücretini güncelledi', 'field', id, `Saatlik ücret: ${price}`);
    res.json({ success: true });
});

app.get('/api/admin/activity', auth, adminOnly, async (req, res) => {
    try {
        const [rows] = await pool.query(`SELECT l.*, u.full_name AS actor_name, u.email AS actor_email
            FROM admin_activity_logs l JOIN users u ON u.id = l.actor_user_id
            ORDER BY l.created_at DESC, l.id DESC LIMIT 200`);
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});
app.post('/api/admin/fields/:id/image', auth, adminOnly, (req, res) => {
    const id = Number(req.params.id);
    const contentType = String(req.headers['content-type'] || '').toLowerCase();
    const allowed = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
    const extension = Object.entries(allowed).find(([type]) => contentType.startsWith(type))?.[1];
    const contentLength = Number(req.headers['content-length'] || 0);
    if (!Number.isInteger(id) || !extension || contentLength > 10 * 1024 * 1024) return res.status(400).json({ error: 'Yalnızca JPG, PNG veya WebP ve en fazla 10 MB görsel yüklenebilir' });
    const imageDir = path.join(__dirname, 'site-images');
    fsModule.mkdirSync(imageDir, { recursive: true });
    const fileName = `field-${id}-${Date.now()}.${extension}`;
    const destination = path.join(imageDir, fileName);
    const stream = fsModule.createWriteStream(destination);
    let bytes = 0; let failed = false;
    req.on('data', chunk => { bytes += chunk.length; if (bytes > 10 * 1024 * 1024) { failed = true; req.destroy(); stream.destroy(); } });
    req.pipe(stream);
    stream.on('finish', async () => {
        if (failed) { await unlinkIfExists(destination); return res.status(413).json({ error: 'Görsel en fazla 10 MB olabilir' }); }
        try {
            if (!await isValidImageFile(destination, extension)) { await unlinkIfExists(destination); return res.status(400).json({ error: 'Yüklenen dosya geçerli bir görsel değil' }); }
            const [[field]] = await pool.query('SELECT image_url FROM fields WHERE id = ?', [id]);
            if (!field) { await unlinkIfExists(destination); return res.status(404).json({ error: 'Saha bulunamadı' }); }
            const imageUrl = `/site-images/${fileName}`;
            await pool.query('UPDATE fields SET image_url = ? WHERE id = ?', [imageUrl, id]);
            if (String(field.image_url || '').startsWith('/site-images/')) await unlinkIfExists(path.join(imageDir, path.basename(field.image_url)));
            res.json({ success: true, image_url: imageUrl });
        } catch (error) { await unlinkIfExists(destination); res.status(500).json({ error: 'Görsel kaydedilemedi' }); }
    });
    stream.on('error', () => res.status(500).json({ error: 'Görsel yüklenemedi' }));
});
app.post('/api/admin/fields/:id/homepage-image', auth, adminOnly, (req, res) => {
    const id = Number(req.params.id);
    const contentType = String(req.headers['content-type'] || '').toLowerCase();
    const allowed = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
    const extension = Object.entries(allowed).find(([type]) => contentType.startsWith(type))?.[1];
    const contentLength = Number(req.headers['content-length'] || 0);
    if (!Number.isInteger(id) || !extension || contentLength > 10 * 1024 * 1024) return res.status(400).json({ error: 'Yalnızca JPG, PNG veya WebP ve en fazla 10 MB görsel yüklenebilir' });
    const imageDir = path.join(__dirname, 'site-images');
    fsModule.mkdirSync(imageDir, { recursive: true });
    const fileName = `homepage-field-${id}-${Date.now()}.${extension}`;
    const destination = path.join(imageDir, fileName);
    const stream = fsModule.createWriteStream(destination);
    let bytes = 0; let failed = false;
    req.on('data', chunk => { bytes += chunk.length; if (bytes > 10 * 1024 * 1024) { failed = true; req.destroy(); stream.destroy(); } });
    req.pipe(stream);
    stream.on('finish', async () => {
        if (failed) { await unlinkIfExists(destination); return res.status(413).json({ error: 'Görsel en fazla 10 MB olabilir' }); }
        try {
            const [[field]] = await pool.query('SELECT homepage_image_url FROM fields WHERE id = ? AND is_active = 1', [id]);
            if (!field) { await unlinkIfExists(destination); return res.status(404).json({ error: 'Saha bulunamadı' }); }
            const imageUrl = `/site-images/${fileName}`;
            await pool.query('UPDATE fields SET homepage_image_url = ? WHERE id = ?', [imageUrl, id]);
            if (String(field.homepage_image_url || '').startsWith('/site-images/')) await unlinkIfExists(path.join(imageDir, path.basename(field.homepage_image_url)));
            res.json({ success: true, homepage_image_url: imageUrl });
        } catch (error) { await unlinkIfExists(destination); res.status(500).json({ error: 'Görsel kaydedilemedi' }); }
    });
    stream.on('error', () => res.status(500).json({ error: 'Görsel yüklenemedi' }));
});
app.get('/api/admin/site-images', auth, adminOnly, async (req, res) => {
    const [rows] = await pool.query('SELECT setting_key, setting_value FROM site_settings');
    res.json({ success: true, images: Object.fromEntries(rows.map(row => [row.setting_key, row.setting_value])) });
});
app.post('/api/admin/site-images/:key', auth, adminOnly, (req, res) => {
    const key = String(req.params.key || '');
    const type = String(req.headers['content-type'] || '').toLowerCase();
    const ext = type.startsWith('image/jpeg') ? 'jpg' : type.startsWith('image/png') ? 'png' : type.startsWith('image/webp') ? 'webp' : null;
    if (!SITE_IMAGE_KEYS.has(key) || !ext || Number(req.headers['content-length'] || 0) > 10 * 1024 * 1024) return res.status(400).json({ error: 'JPG, PNG veya WebP biçiminde en fazla 10 MB görsel yükleyin' });
    const imageDir = path.join(__dirname, 'site-images'); fsModule.mkdirSync(imageDir, { recursive: true });
    const fileName = `${key}-${Date.now()}.${ext}`, destination = path.join(imageDir, fileName); const stream = fsModule.createWriteStream(destination); let bytes = 0, failed = false;
    req.on('data', chunk => { bytes += chunk.length; if (bytes > 10 * 1024 * 1024) { failed = true; req.destroy(); stream.destroy(); } }); req.pipe(stream);
    stream.on('finish', async () => { try {
        if (failed) { await unlinkIfExists(destination); return res.status(413).json({ error: 'Görsel en fazla 10 MB olabilir' }); }
        if (!await isValidImageFile(destination, ext)) { await unlinkIfExists(destination); return res.status(400).json({ error: 'Yüklenen dosya geçerli bir görsel değil' }); }
        const [[previous]] = await pool.query('SELECT setting_value FROM site_settings WHERE setting_key = ?', [key]);
        const imageUrl = `/site-images/${fileName}`;
        await pool.query('INSERT INTO site_settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)', [key, imageUrl]);
        if (String(previous?.setting_value || '').startsWith('/site-images/')) await unlinkIfExists(path.join(imageDir, path.basename(previous.setting_value)));
        res.json({ success: true, image_url: imageUrl });
    } catch { await unlinkIfExists(destination); res.status(500).json({ error: 'Görsel kaydedilemedi' }); }});
    stream.on('error', () => res.status(500).json({ error: 'Görsel yüklenemedi' }));
});

app.get('/api/notifications', auth, async (req, res) => {
    const [rows] = await pool.query('SELECT id, title, message, type, is_read, created_at FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50', [req.user.id]);
    res.json(rows);
});
app.patch('/api/notifications/:id/read', auth, async (req, res) => {
    await pool.query('UPDATE notifications SET is_read = TRUE WHERE id = ? AND user_id = ?', [Number(req.params.id), req.user.id]);
    res.json({ success: true });
});

// Get all users (admin)
app.get('/api/admin/users', auth, adminOnly, async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT id, full_name, email, phone, role, avatar_color, is_active, created_at FROM users ORDER BY created_at DESC');
        res.json(rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Create a member or another administrator. This route is deliberately separate
// from public registration: only an already authenticated administrator can
// assign the admin role.
app.post('/api/admin/users', auth, adminOnly, async (req, res) => {
    const fullName = String(req.body.full_name || '').trim();
    const email = normalizeEmail(req.body.email);
    const phone = String(req.body.phone || '').trim();
    const password = String(req.body.password || '');
    const role = req.body.role === 'admin' ? 'admin' : 'customer';
    if (fullName.length < 2 || fullName.length > 100 || !emailPattern.test(email) || password.length < 8 || phone.length > 20) {
        return res.status(400).json({ error: 'Ad soyad, geçerli e-posta ve en az 8 karakter şifre gereklidir' });
    }
    try {
        const [[existing]] = await pool.query('SELECT id FROM users WHERE email = ?', [email]);
        if (existing) return res.status(409).json({ error: 'Bu e-posta zaten kayıtlı' });
        const colors = ['#4ade80', '#60a5fa', '#f472b6', '#fb923c', '#a78bfa'];
        const avatarColor = colors[Math.floor(Math.random() * colors.length)];
        const passwordHash = await bcrypt.hash(password, 12);
        const [result] = await pool.query(
            'INSERT INTO users (full_name, email, phone, password_hash, role, avatar_color, kvkk_approved, contract_approved) VALUES (?, ?, ?, ?, ?, ?, TRUE, TRUE)',
            [fullName, email, phone, passwordHash, role, avatarColor]
        );
        await createNotification(result.insertId, 'Hesabınız oluşturuldu', role === 'admin' ? 'Yönetici hesabınız oluşturuldu.' : 'Üyeliğiniz yönetim tarafından oluşturuldu.', 'system');
        await logAdminActivity(req.user.id, 'Kullanıcı hesabı oluşturdu', 'user', result.insertId, `${fullName} · ${role === 'admin' ? 'Yönetici' : 'Üye'}`);
        res.status(201).json({ success: true, user: { id: result.insertId, full_name: fullName, email, phone, role, avatar_color: avatarColor } });
    } catch (err) {
        console.error('Yönetici kullanıcı oluşturma hatası:', err);
        res.status(500).json({ error: 'Kullanıcı oluşturulamadı' });
    }
});

app.get('/api/admin/users/:id', auth, adminOnly, async (req, res) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ error: 'Geçersiz kullanıcı' });
    try {
        const [[user]] = await pool.query('SELECT id, full_name, email, phone, role, avatar_color, is_active, created_at, birth_date, birth_place, parent_name, parent_phone, city, district, address, reference_source, blood_type, health_conditions, kvkk_approved, contract_approved FROM users WHERE id = ?', [id]);
        if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        res.json(user);
    } catch { res.status(500).json({ error: 'Kullanıcı bilgisi alınamadı' }); }
});

// Toggle user active/inactive (admin)
app.patch('/api/admin/users/:id/toggle', auth, adminOnly, async (req, res) => {
    try {
        const [[user]] = await pool.query('SELECT full_name, is_active FROM users WHERE id = ?', [req.params.id]);
        if (!user) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        await pool.query('UPDATE users SET is_active = NOT is_active WHERE id = ?', [req.params.id]);
        await logAdminActivity(req.user.id, user.is_active ? 'Kullanıcıyı devre dışı bıraktı' : 'Kullanıcıyı aktifleştirdi', 'user', req.params.id, user.full_name);
        res.json({ success: true });
    } catch (err) { res.status(500).json({ error: err.message }); }
});

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'ok', timestamp: new Date().toISOString() }));

const PORT = process.env.PORT || 3000;

// 🎬 VIDEO ROUTES 🎬
// Maç videoları herkese açık içeriktir. Arama ve oynatma için kullanıcı
// oturumu gerekmez; yönetim uçları ve kesit üretimi aşağıda korumalı kalır.
app.get('/api/videos/search', async (req, res) => {
    const { date, time_slot, field_id } = req.query;
    const fieldId = Number(field_id);
    if (!datePattern.test(String(date)) || !SLOT_HOURS.includes(time_slot) || !Number.isInteger(fieldId)) return res.status(400).json({ error: 'Geçersiz video araması' });
    try {
        const [rows] = await pool.query('SELECT id FROM match_videos WHERE date = ? AND time_slot = ? AND field_id = ?', [date, time_slot, fieldId]);
        if (rows.length) {
            res.json({ success: true, video_id: rows[0].id });
        } else {
            res.json({ success: false, message: 'Video bulunamadı' });
        }
    } catch(e) { res.status(500).json({ error: e.message }); }
});

async function getAuthorizedVideo(user, videoId) {
    if (!Number.isInteger(videoId)) return null;
    if (user.role === 'admin') {
        const [[video]] = await pool.query('SELECT id, video_url FROM match_videos WHERE id = ?', [videoId]);
        return video || null;
    }
    const [[video]] = await pool.query(
        "SELECT v.id, v.video_url FROM match_videos v JOIN reservations r ON r.field_id = v.field_id AND r.date = v.date AND r.time_slot = v.time_slot WHERE v.id = ? AND r.user_id = ? AND r.status IN ('confirmed', 'completed')",
        [videoId, user.id]
    );
    return video || null;
}

async function getPublicVideo(videoId) {
    if (!Number.isInteger(videoId)) return null;
    const [[video]] = await pool.query('SELECT id, video_url FROM match_videos WHERE id = ?', [videoId]);
    return video || null;
}

registerPublicVideoClips(app, {
    getPublicVideo,
    uploadsDir: path.resolve(__dirname, 'uploads'),
});

app.get('/api/videos/:id/content', async (req, res) => {
    try {
        const video = await getPublicVideo(Number(req.params.id));
        if (!video) return res.status(404).json({ error: 'Video bulunamadı' });
        const uploadsDir = path.resolve(__dirname, 'uploads');
        const filePath = path.resolve(uploadsDir, path.basename(video.video_url));
        if (!filePath.startsWith(`${uploadsDir}${path.sep}`) || !fsModule.existsSync(filePath)) return res.status(404).json({ error: 'Video dosyası bulunamadı' });
        res.sendFile(filePath);
    } catch { res.status(500).json({ error: 'Video açılamadı' }); }
});

app.get('/api/admin/videos', auth, adminOnly, async (req, res) => {
    try {
        const [rows] = await pool.query('SELECT v.*, f.name as field_name FROM match_videos v JOIN fields f ON v.field_id = f.id ORDER BY v.date DESC, v.time_slot DESC');
        res.json({ success: true, videos: rows });
    } catch(e) { res.status(500).json({ error: e.message }); }
});


app.post('/api/admin/videos/upload', auth, adminOnly, (req, res) => {
    const maxUploadBytes = 100 * 1024 * 1024;
    const contentLength = Number(req.headers['content-length'] || 0);
    const contentType = String(req.headers['content-type'] || '').toLowerCase();
    const requestedName = String(req.query.fileName || 'video.mp4');
    if (contentLength > maxUploadBytes) return res.status(413).json({ error: 'Video en fazla 100 MB olabilir' });
    // Bazı tarayıcılar File nesnesini application/octet-stream olarak gönderir.
    // Bu durumda uzantı kontrolü video türünü güvenli biçimde doğrulamaya devam eder.
    if (!['video/mp4', 'video/webm', 'video/quicktime', 'application/octet-stream'].some(type => contentType.startsWith(type)) || !/\.(mp4|webm|mov)$/i.test(requestedName)) return res.status(400).json({ error: 'Yalnızca MP4, WebM veya MOV video yüklenebilir' });
    const date = String(req.query.date || '');
    const timeSlot = String(req.query.time_slot || '');
    const fieldId = Number(req.query.field_id);
    if (!datePattern.test(date) || !SLOT_HOURS.includes(timeSlot) || !Number.isInteger(fieldId)) return res.status(400).json({ error: 'Video bilgileri geçersiz' });
    const fileName = Date.now() + '_' + requestedName.replace(/[^a-zA-Z0-9.-]/g, '_');
    const destDir = path.join(__dirname, 'uploads');
    
    // Ensure dir exists
    if (!fsModule.existsSync(destDir)){
        fsModule.mkdirSync(destDir, { recursive: true });
    }
    
    const dest = path.join(destDir, fileName);
    const writeStream = fsModule.createWriteStream(dest);
    
    let bytesReceived = 0;
    let rejected = false;
    req.on('data', chunk => {
        bytesReceived += chunk.length;
        if (!rejected && bytesReceived > maxUploadBytes) {
            rejected = true;
            req.destroy();
            writeStream.destroy();
            fsModule.unlink(dest, () => {});
        }
    });
    req.pipe(writeStream);
    
    writeStream.on('finish', async () => {
        const video_url = '/uploads/' + fileName;
        if (rejected) return res.status(413).json({ error: 'Video en fazla 100 MB olabilir' });
        try {
            const [[previous]] = await pool.query('SELECT video_url FROM match_videos WHERE field_id = ? AND date = ? AND time_slot = ?', [fieldId, date, timeSlot]);
            await pool.query('INSERT INTO match_videos (field_id, date, time_slot, video_url) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE video_url = ?, created_at = CURRENT_TIMESTAMP', [fieldId, date, timeSlot, video_url, video_url]);
            if (previous?.video_url && previous.video_url !== video_url) await unlinkIfExists(path.join(destDir, path.basename(previous.video_url)));
            const [watchers] = await pool.query("SELECT r.user_id, f.name AS field_name FROM reservations r JOIN fields f ON f.id = r.field_id WHERE r.field_id = ? AND r.date = ? AND r.time_slot = ? AND r.status IN ('confirmed','completed')", [fieldId, date, timeSlot]);
            await Promise.all(watchers.map(watcher => createNotification(watcher.user_id, 'Maç videonuz hazır', `${watcher.field_name} · ${date} · ${timeSlot} kaydını 7 gün içinde izleyebilir veya kesit alabilirsiniz.`, 'video')));
            res.json({ success: true, video_url });
        } catch(e) { res.status(500).json({ error: e.message }); }
    });
    
    req.on('error', (err) => {
        res.status(500).json({ error: 'Upload failed' });
    });
});

app.post('/api/admin/videos', auth, adminOnly, async (req, res) => {
    const { date, time_slot, field_id, video_url } = req.body;
    try {
        await pool.query('INSERT INTO match_videos (field_id, date, time_slot, video_url) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE video_url = ?, created_at = CURRENT_TIMESTAMP', [field_id, date, time_slot, video_url, video_url]);
        res.json({ success: true });
    } catch(e) { res.status(500).json({ error: e.message }); }
});

app.delete('/api/admin/videos/:id', auth, adminOnly, async (req, res) => {
    try {
        const [[video]] = await pool.query('SELECT id, video_url FROM match_videos WHERE id = ?', [req.params.id]);
        if (!video) return res.status(404).json({ error: 'Video bulunamadı' });
        const [clips] = await pool.query('SELECT file_name FROM video_clips WHERE video_id = ?', [video.id]);
        const uploadsDir = path.resolve(__dirname, 'uploads');
        await Promise.all([unlinkIfExists(path.join(uploadsDir, path.basename(video.video_url))), ...clips.map(clip => unlinkIfExists(path.join(uploadsDir, path.basename(clip.file_name)) ))]);
        await pool.query('DELETE FROM match_videos WHERE id = ?', [video.id]);
        res.json({ success: true });
    } catch(e) { res.status(500).json({ error: e.message }); }
});


app.get('/api/videos/clips/:fileName/content', auth, async (req, res) => {
    const fileName = path.basename(String(req.params.fileName || ''));
    const videoId = Number(req.query.video_id);
    if (!/^kesit_[0-9a-f-]{36}\.mp4$/i.test(fileName) || !Number.isInteger(videoId)) return res.status(400).json({ error: 'Geçersiz kesit dosyası' });
    try {
        const video = await getAuthorizedVideo(req.user, videoId);
        const [[clip]] = await pool.query('SELECT video_id, user_id FROM video_clips WHERE file_name = ?', [fileName]);
        if (!video || !clip || Number(clip.video_id) !== videoId || (req.user.role !== 'admin' && Number(clip.user_id) !== Number(req.user.id))) return res.status(403).json({ error: 'Bu kesiti indirme yetkiniz yok' });
        const uploadsDir = path.resolve(__dirname, 'uploads');
        const filePath = path.resolve(uploadsDir, fileName);
        if (!filePath.startsWith(`${uploadsDir}${path.sep}`) || !fsModule.existsSync(filePath)) return res.status(404).json({ error: 'Kesit dosyası bulunamadı' });
        res.download(filePath, fileName);
    } catch { res.status(500).json({ error: 'Kesit indirilemedi' }); }
});

app.post('/api/videos/clip', auth, async (req, res) => {
    const { video_id, start, end } = req.body;
    const startSeconds = Number(start);
    const endSeconds = Number(end);
    if (!Number.isInteger(Number(video_id)) || !Number.isFinite(startSeconds) || !Number.isFinite(endSeconds) || startSeconds < 0 || endSeconds <= startSeconds || endSeconds - startSeconds > 300) return res.status(400).json({ error: 'Geçersiz kesit bilgileri' });
    const video = await getAuthorizedVideo(req.user, Number(video_id));
    if (!video) return res.status(404).json({ error: 'Video bulunamadı veya erişim izniniz yok' });
    const uploadsDir = path.resolve(__dirname, 'uploads');
    const inputPath = path.resolve(uploadsDir, path.basename(video.video_url));
    if (!inputPath.startsWith(`${uploadsDir}${path.sep}`) || !fsModule.existsSync(inputPath)) return res.status(404).json({ error: 'Video bulunamadı' });
    const outputFileName = 'kesit_' + crypto.randomUUID() + '.mp4';
    const outputPath = path.join(uploadsDir, outputFileName);
    const ffmpeg = spawn('ffmpeg', ['-ss', String(startSeconds), '-i', inputPath, '-t', String(endSeconds - startSeconds), '-vf', DOWNLOADED_VIDEO_WATERMARK, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', outputPath], { shell: false });
    let stderr = '';
    ffmpeg.stderr.on('data', chunk => { stderr += chunk.toString(); });
    ffmpeg.on('error', () => res.status(500).json({ error: 'Video işleme başlatılamadı' }));
    ffmpeg.on('close', async code => {
        if (code !== 0) {
            fsModule.unlink(outputPath, () => {});
            console.error('FFmpeg Error:', stderr.slice(-1000));
            return res.status(500).json({ error: 'Video kesilemedi' });
        }
        await pool.query('INSERT INTO video_clips (file_name, video_id, user_id) VALUES (?, ?, ?)', [outputFileName, Number(video_id), req.user.id]);
        res.json({ success: true, clip_url: '/api/videos/clips/' + encodeURIComponent(outputFileName) + '/content?video_id=' + encodeURIComponent(String(video_id)) });
    });
});


const Iyzipay = require('iyzipay');

if (!process.env.IYZICO_API_KEY || !process.env.IYZICO_SECRET_KEY) {
    console.error('İyzico yapılandırması eksik: IYZICO_API_KEY ve IYZICO_SECRET_KEY tanımlanmalıdır.');
}
const iyzipay = new Iyzipay({
    apiKey: process.env.IYZICO_API_KEY,
    secretKey: process.env.IYZICO_SECRET_KEY,
    uri: process.env.IYZICO_API_URL || 'https://sandbox-api.iyzipay.com'
});

// Checkout Form sonucu bazı sağlayıcı akışlarında conversationId yerine basketId
// alanını döndürebilir. İkisi de ödeme başlatılırken aynı, rastgele üretilen niyet
// kimliğiyle gönderilir; bu yüzden güvenli bir çapraz kontrol olarak kullanılır.
function paymentResultMatchesIntent(paymentResult, intentId) {
    const expectedId = String(intentId);
    return String(paymentResult?.conversationId || '') === expectedId ||
        String(paymentResult?.basketId || '') === expectedId;
}

// Checkout formu ilk kez açıldığında İyzico, ödeme henüz gönderilmediği için
// retrieve çağrısına "tokena ait ödeme bilgisi bulunamadı" ile dönebilir. Bu,
// bir ödeme hatası değil beklenen pending durumudur.
function paymentResultIsStillPending(error, result) {
    const message = String(error?.message || result?.errorMessage || '').toLocaleLowerCase('tr-TR');
    return message.includes('tokena ait ödeme bilgisi bulunamadı') ||
        message.includes('payment information for the token') ||
        message.includes('payment not found');
}

async function finalizePaymentIntent(intentId, paymentResult) {
    const connection = await pool.getConnection();
    let lockName;
    try {
        await connection.beginTransaction();
        const [[intent]] = await connection.query('SELECT * FROM payment_intents WHERE id = ? FOR UPDATE', [intentId]);
        if (!intent) throw new Error('Ödeme niyeti bulunamadı');
        if (intent.status === 'paid') {
            await connection.commit();
            return { alreadyPaid: true };
        }
        if (!paymentResultMatchesIntent(paymentResult, intent.id) || Math.abs(Number(paymentResult.paidPrice || paymentResult.price) - Number(intent.total_amount)) > 0.01) {
            throw new Error('Sağlayıcı ödeme yanıtı doğrulanamadı');
        }
        // Iyzico has already verified SUCCESS before this function is called. Do not
        // discard a captured payment merely because the local 15-minute UI window
        // elapsed; create the reservation if its slot is still available.
        if (!['pending', 'expired'].includes(intent.status)) throw new Error('Ödeme niyeti geçersiz');
        lockName = `reservation:${intent.field_id}:${toDateString(intent.date)}`;
        const [[lock]] = await connection.query('SELECT GET_LOCK(?, 5) AS acquired', [lockName]);
        if (!lock.acquired) throw new Error('Rezervasyon kilidi alınamadı');
        const [existing] = await connection.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed') FOR UPDATE", [intent.date, intent.field_id]);
        if (existing.some(row => row.time_slot === intent.time_slot)) throw new Error('Ödeme sırasında saat doldu');
        const transactionId = paymentResult.itemTransactions?.[0]?.paymentTransactionId || null;
        await connection.query("INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, payment_status, payment_method, payment_transaction_id, iyzico_payment_id) VALUES (?, ?, ?, ?, ?, ?, 'confirmed', 'paid', 'online', ?, ?)", [intent.user_id, intent.field_id, intent.date, intent.time_slot, intent.duration_hours, intent.total_amount, transactionId, paymentResult.paymentId || null]);
        await connection.query("UPDATE payment_intents SET status = 'paid', payment_transaction_id = ?, iyzico_payment_id = ? WHERE id = ?", [transactionId, paymentResult.paymentId || null, intentId]);
        await connection.commit();
        const [[field]] = await pool.query('SELECT name FROM fields WHERE id = ?', [intent.field_id]);
        const detail = `${field?.name || 'Saha'} · ${toDateString(intent.date)} · ${intent.time_slot}`;
        await createNotification(intent.user_id, 'Ödemeniz alındı', `${detail}. Rezervasyonunuz kesinleşti ve iptal edilemez.`, 'payment');
        await notifyAdmins('Online ödeme ile rezervasyon', detail, 'payment');
        return { paid: true };
    } catch (error) {
        await connection.rollback();
        throw error;
    } finally {
        if (lockName) { try { await connection.query('SELECT RELEASE_LOCK(?)', [lockName]); } catch {} }
        connection.release();
    }
}

async function finalizeAcademyPaymentIntent(intentId, paymentResult) {
    const connection = await pool.getConnection();
    try {
        await connection.beginTransaction();
        const [[intent]] = await connection.query('SELECT * FROM academy_payment_intents WHERE id = ? FOR UPDATE', [intentId]);
        if (!intent) throw new Error('Abonelik ödeme niyeti bulunamadı');
        if (intent.status === 'paid') { await connection.commit(); return { alreadyPaid: true }; }
        if (intent.status !== 'pending') throw new Error('Abonelik ödeme niyeti geçersiz veya süresi dolmuş');
        if (Math.abs(Number(paymentResult.paidPrice || paymentResult.price) - Number(intent.total_amount)) > 0.01) throw new Error('Sağlayıcı ödeme tutarı uyuşmuyor');
        const [update] = await connection.query(
            "UPDATE reservations SET status = 'confirmed', payment_status = 'paid', payment_transaction_id = ?, iyzico_payment_id = ? WHERE user_id = ? AND status = 'pending' AND notes LIKE ?",
            [paymentResult.itemTransactions?.[0]?.paymentTransactionId || null, paymentResult.paymentId || null, intent.user_id, `%group: ${intent.group_id}%`]
        );
        if (!update.affectedRows) throw new Error('Abonelik rezervasyonu bulunamadı');
        await connection.query("UPDATE academy_payment_intents SET status = 'paid', payment_transaction_id = ?, iyzico_payment_id = ? WHERE id = ?", [paymentResult.itemTransactions?.[0]?.paymentTransactionId || null, paymentResult.paymentId || null, intentId]);
        await connection.commit();
        return { paid: true };
    } catch (error) { await connection.rollback(); throw error; } finally { connection.release(); }
}

app.post('/api/payment/academy-checkout', auth, paymentRateLimit, async (req, res) => {
    const { group_id } = req.body;
    if (!group_id) return res.status(400).json({ error: 'group_id gerekli' });
    let priceStr;
    let packageName;
    let academyIntent;
    try {
        const [[intent]] = await pool.query(
            "SELECT * FROM academy_payment_intents WHERE group_id = ? AND user_id = ? AND status = 'pending' AND expires_at > NOW() FOR UPDATE",
            [group_id, req.user.id]
        );
        if (!intent) return res.status(404).json({ error: 'Geçerli bir ödeme oturumu bulunamadı' });
        academyIntent = intent;
        const [rows] = await pool.query(
            "SELECT total_amount, notes FROM reservations WHERE user_id = ? AND status = 'pending' AND notes LIKE ?",
            [req.user.id, `%group: ${escapeLike(group_id)}%`]
        );
        if (!rows.length) return res.status(404).json({ error: 'Ödeme bekleyen abonelik bulunamadı' });
        const total = rows.reduce((sum, row) => sum + Number(row.total_amount), 0);
        if (Math.abs(total - Number(intent.total_amount)) > 0.01) throw new Error('Ödeme tutarı uyuşmuyor');
        packageName = String(rows[0].notes || '').split(' | ')[0].replace('Abonelik: ', '') || 'Abonelik';
        priceStr = total.toFixed(2);
    } catch (err) {
        return res.status(500).json({ error: 'Ödeme bilgisi hazırlanamadı' });
    }

    const request = {
        locale: Iyzipay.LOCALE.TR,
        conversationId: `academy:${academyIntent.id}`,
        price: priceStr,
        paidPrice: priceStr,
        currency: Iyzipay.CURRENCY.TRY,
        basketId: 'ACADEMY',
        paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
        callbackUrl: PAYMENT_CALLBACK_URL,
        enabledInstallments: [2, 3, 6, 9],
        buyer: {
            id: 'BY789',
            name: req.user ? req.user.full_name : 'Test',
            surname: 'User',
            gsmNumber: '+905350000000',
            email: 'email@email.com',
            identityNumber: IYZICO_TECHNICAL_IDENTITY,
            lastLoginDate: '2024-01-01 10:00:00',
            registrationDate: '2024-01-01 10:00:00',
            registrationAddress: 'Nidakule Göztepe',
            ip: '85.34.78.112',
            city: 'Istanbul',
            country: 'Turkey',
            zipCode: '34732'
        },
        shippingAddress: { contactName: 'Test User', city: 'Istanbul', country: 'Turkey', address: 'Nidakule', zipCode: '34732' },
        billingAddress: { contactName: 'Test User', city: 'Istanbul', country: 'Turkey', address: 'Nidakule', zipCode: '34732' },
        basketItems: [
            { id: academyIntent.id, name: packageName, category1: 'Abonelik', itemType: Iyzipay.BASKET_ITEM_TYPE.VIRTUAL, price: priceStr }
        ]
    };

    iyzipay.checkoutFormInitialize.create(request, (err, result) => {
        if (err || result.status !== 'success' || !result.token) {
            return res.status(502).json({ error: 'Ödeme formu hazırlanamadı' });
        }
        pool.query('UPDATE academy_payment_intents SET checkout_token = ? WHERE id = ? AND status = \'pending\'', [result.token, academyIntent.id])
            .then(() => res.json({
                success: true,
                payment_intent_id: academyIntent.id,
                checkoutFormContent: result.checkoutFormContent
            }))
            .catch(() => res.status(500).json({ error: 'Ödeme oturumu kaydedilemedi' }));
    });
});

app.post('/api/payment/checkout', auth, paymentRateLimit, async (req, res) => {
    const { date, time_slot, field_id, duration_hours = 1 } = req.body;
    const fieldId = Number(field_id);
    const duration = Number(duration_hours);
    if (!datePattern.test(String(date)) || !SLOT_HOURS.includes(time_slot) || !Number.isInteger(fieldId) || duration !== 1) return res.status(400).json({ error: 'Rezervasyonlar yalnızca 09:00–02:00 arasında ve 1 saatlik yapılabilir' });
    const now = istanbulNow();
    if (slotIsPast(date, time_slot, now)) return res.status(400).json({ error: 'Geçmiş saatler için ödeme başlatılamaz' });
    if (!SLOT_HOURS.includes(SLOT_HOURS[SLOT_HOURS.indexOf(time_slot) + duration - 1])) return res.status(400).json({ error: 'Seçilen süre tesisin çalışma saatlerini aşıyor' });

    let fieldPrice = 0;
    let fieldName = 'Saha Rezervasyonu';
    let customer;
    const intentId = crypto.randomUUID();

    try {
        const [[field]] = await pool.query('SELECT id, name, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [fieldId]);
        if (!field) return res.status(404).json({ error: 'Saha bulunamadı veya kullanıma kapalı' });
        const [existing] = await pool.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')", [date, fieldId]);
        if (existing.some(row => row.time_slot === time_slot)) return res.status(409).json({ error: 'Seçtiğiniz saat dolu' });
        const [[user]] = await pool.query('SELECT full_name, email, phone FROM users WHERE id = ?', [req.user.id]);
        if (!user) return res.status(401).json({ error: 'Kullanıcı bulunamadı' });
        fieldPrice = Number(field.price_per_hour) * duration;
        fieldName = field.name;
        customer = user;
        await pool.query('INSERT INTO payment_intents (id, user_id, field_id, date, time_slot, duration_hours, total_amount, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL 15 MINUTE))', [intentId, req.user.id, fieldId, date, time_slot, duration, fieldPrice]);
    } catch (err) {
        console.error('Payment intent error:', err);
        return res.status(500).json({ error: 'Ödeme başlatılamadı' });
    }

    const [firstName, ...surnameParts] = String(customer.full_name || 'Test Kullanıcı').trim().split(/\s+/);
    const priceStr = fieldPrice.toFixed(2);
    console.log(`Checkout Request: intent_id=${intentId}, priceStr=${priceStr}`);

    const request = {
        locale: Iyzipay.LOCALE.TR,
        // Iyzico returns this value in the callback. Keep it to a plain UUID so it
        // remains an unambiguous, provider-safe payment-intent identifier.
        conversationId: intentId,
        price: priceStr,
        paidPrice: priceStr,
        currency: Iyzipay.CURRENCY.TRY,
        // Keep a second provider-returned correlation key. Some checkout responses
        // omit conversationId but retain basketId.
        basketId: intentId,
        paymentGroup: Iyzipay.PAYMENT_GROUP.PRODUCT,
        callbackUrl: PAYMENT_CALLBACK_URL,
        enabledInstallments: [2, 3, 6, 9],
        buyer: {
            id: 'BY789',
            name: firstName || 'Test',
            surname: surnameParts.join(' ') || 'Kullanıcı',
            gsmNumber: String(customer.phone || '+905350000000').replace(/\s+/g, ''),
            email: customer.email || 'email@email.com',
            identityNumber: IYZICO_TECHNICAL_IDENTITY,
            lastLoginDate: '2015-10-05 12:43:35',
            registrationDate: '2013-04-21 15:12:09',
            registrationAddress: 'Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1',
            ip: '85.34.78.112',
            city: 'Istanbul',
            country: 'Turkey',
            zipCode: '34732'
        },
        shippingAddress: {
            contactName: customer.full_name || 'Test Kullanıcı',
            city: 'Istanbul',
            country: 'Turkey',
            address: 'Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1',
            zipCode: '34732'
        },
        billingAddress: {
            contactName: customer.full_name || 'Test Kullanıcı',
            city: 'Istanbul',
            country: 'Turkey',
            address: 'Nidakule Göztepe, Merdivenköy Mah. Bora Sok. No:1',
            zipCode: '34732'
        },
        basketItems: [
            {
                id: 'BI101',
                name: fieldName,
                category1: 'Hizmet',
                itemType: Iyzipay.BASKET_ITEM_TYPE.VIRTUAL,
                price: priceStr
            }
        ]
    };

    iyzipay.checkoutFormInitialize.create(request, function (err, result) {
        if (err || result?.status === 'failure' || !result?.token) {
            console.error(err || result.errorMessage);
            pool.query("UPDATE payment_intents SET status = 'expired' WHERE id = ?", [intentId]).catch(() => {});
            return res.status(500).json({ error: 'İyzico ödeme formu hazırlanamadı' });
        }
        pool.query('UPDATE payment_intents SET checkout_token = ? WHERE id = ?', [result.token, intentId])
            .then(() => res.json({
                success: true,
                payment_intent_id: intentId,
                checkoutFormContent: result.checkoutFormContent
            }))
            .catch(dbErr => {
                console.error('Ödeme formu belirteci kaydedilemedi:', dbErr);
                res.status(500).json({ error: 'Ödeme başlatılamadı' });
            });
    });
});

// Local development cannot receive iyzico's server callback at localhost. The signed-in
// browser therefore asks this endpoint to retrieve the authoritative payment result.
app.get('/api/payment/intents/:intentId/status', auth, paymentStatusRateLimit, async (req, res) => {
    const intentId = String(req.params.intentId || '');
    try {
        let [[intent]] = await pool.query(
            'SELECT id, status, checkout_token, expires_at, total_amount FROM payment_intents WHERE id = ? AND user_id = ?',
            [intentId, req.user.id]
        );
        const academyPayment = !intent;
        if (!intent) {
            [[intent]] = await pool.query(
                'SELECT id, status, checkout_token, expires_at, total_amount FROM academy_payment_intents WHERE id = ? AND user_id = ?',
                [intentId, req.user.id]
            );
        }
        if (!intent) return res.status(404).json({ error: 'Ödeme işlemi bulunamadı' });
        if (intent.status === 'paid') return res.json({ status: 'paid' });
        if (intent.status !== 'pending') {
            return res.json({ status: 'expired' });
        }
        if (new Date(intent.expires_at).getTime() < Date.now()) return res.json({ status: 'expired' });
        if (!intent.checkout_token) return res.status(409).json({ error: 'Ödeme doğrulama bilgisi bulunamadı' });

        iyzipay.checkoutForm.retrieve({ token: intent.checkout_token }, async (err, result) => {
            if (err || result?.status !== 'success') {
                if (paymentResultIsStillPending(err, result)) {
                    return res.json({ status: 'pending' });
                }
                console.error('İyzico ödeme durumu alınamadı:', err || result?.errorMessage);
                return res.status(502).json({ error: 'Ödeme durumu doğrulanamadı' });
            }
            if (result.paymentStatus === 'SUCCESS') {
                const resultMatchesIntent = academyPayment
                    ? String(result?.conversationId || '') === `academy:${intentId}`
                    : paymentResultMatchesIntent(result, intentId);
                if (!resultMatchesIntent || Math.abs(Number(result.paidPrice || result.price) - Number(intent.total_amount || 0)) > 0.01) {
                    return res.status(409).json({ error: 'Ödeme yanıtı doğrulanamadı' });
                }
                try {
                    if (academyPayment) await finalizeAcademyPaymentIntent(intentId, result);
                    else await finalizePaymentIntent(intentId, result);
                    return res.json({ status: 'paid' });
                } catch (finalizeError) {
                    console.error('Ödeme rezervasyona dönüştürülemedi:', finalizeError);
                    return res.status(409).json({ error: finalizeError.message });
                }
            }
            if (['FAILURE', 'CANCELLED'].includes(result.paymentStatus)) {
                await pool.query(
                    `UPDATE ${academyPayment ? 'academy_payment_intents' : 'payment_intents'} SET status = 'expired' WHERE id = ? AND status = 'pending'`,
                    [intentId]
                );
                return res.json({ status: 'failed' });
            }
            return res.json({ status: 'pending' });
        });
    } catch (error) {
        console.error('Ödeme durumu sorgulanamadı:', error);
        res.status(500).json({ error: 'Ödeme durumu sorgulanamadı' });
    }
});

app.get('/api/payment/callback', (req, res) => {
    res.redirect(302, '/pages/user/dashboard.html');
});

app.post('/api/payment/callback', fixedWindowRateLimit(apiAttempts, 60, 15 * 60 * 1000, req => `callback:${req.ip}`), (req, res) => {
    const { token } = req.body;
    if (!token) return res.status(400).send('Token eksik');

    iyzipay.checkoutForm.retrieve({ token }, async (err, result) => {
        if (err || result.status !== 'success') {
            return res.status(400).send('<h2>Ödeme doğrulanamadı.</h2><p>Lütfen tesisle iletişime geçin.</p>');
        }

        if (result.paymentStatus === 'SUCCESS') {
            const conversationId = String(result.conversationId || '');
            const basketId = String(result.basketId || '');
            try {
                if (conversationId.startsWith('academy:')) {
                    const academyIntentId = conversationId.slice('academy:'.length);
                    // İyzico callback'te form tokenını farklı biçimde döndürebilir.
                    // Token ile sonucu İyzico API'sinden zaten sunucu tarafında doğruladık;
                    // bu nedenle ödeme sağlayıcısının döndürdüğü benzersiz conversationId
                    // üzerinden ilgili niyeti buluyoruz.
                    const [[academyIntent]] = await pool.query('SELECT id FROM academy_payment_intents WHERE id = ?', [academyIntentId]);
                    if (!academyIntent) throw new Error('Abonelik ödeme oturumu eşleştirilemedi');
                    await finalizeAcademyPaymentIntent(academyIntent.id, result);
                } else {
                    const [[intent]] = await pool.query('SELECT id FROM payment_intents WHERE id IN (?, ?)', [conversationId, basketId]);
                    if (!intent) throw new Error('Ödeme oturumu eşleştirilemedi');
                    await finalizePaymentIntent(intent.id, result);
                }
            } catch (dbErr) {
                console.error('DB Error on callback:', dbErr);
                return res.status(500).send('<h2>Ödeme kaydı oluşturulamadı. Lütfen tesisle iletişime geçin.</h2>');
            }

            res.send(`
                <html>
                    <head>
                        <title>Ödeme Başarılı</title>
                        <meta charset="utf-8">
                        <meta name="viewport" content="width=device-width, initial-scale=1">
                    </head>
                    <body style="display:flex; justify-content:center; align-items:center; height:100vh; font-family:sans-serif; background:#f0f9ff; text-align:center;">
                        <div style="background:#fff; padding:40px; border-radius:12px; box-shadow:0 10px 25px rgba(0,0,0,0.1);">
                            <div style="font-size:64px; margin-bottom:16px;">✅</div>
                            <h2 style="color:#0369a1; margin-top:0;">Ödeme Başarılı!</h2>
                            <p style="color:#475569;">Ödemeniz alındı. Uygulamaya dönebilirsiniz.</p>
                            <a href="${PAYMENT_BROWSER_PANEL_URL}" target="_top" onclick="if (/(?:; wv\\)|\\bVersion\\/4\\.0\\b)/i.test(navigator.userAgent)) this.href='${PAYMENT_PANEL_URL}'" style="display:inline-block; margin-top:12px; padding:13px 28px; border-radius:10px; background:#0b6fb3; color:#fff; font-weight:700; text-decoration:none;">Panele dön</a>
                        </div>
                    </body>
                </html>
            `);
        } else {
            res.status(400).send('<h2>Ödeme tamamlanamadı.</h2><p>Lütfen tekrar deneyin.</p>');
        }
    });
});

app.listen(PORT, () => console.log(`🚀 ProSaha API çalışıyor: http://localhost:${PORT}`));
