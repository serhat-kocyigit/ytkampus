const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

const newEndpoint = `
// Academy Subscription Endpoint
app.post('/api/reservations/academy', auth, async (req, res) => {
    const { field_id, package_name, schedule, duration_hours = 1 } = req.body;
    // schedule is array like: [{day: 1, time: '18:00'}, {day: 3, time: '19:00'}]
    if (!field_id || !package_name || !schedule || !Array.isArray(schedule)) {
       return res.status(400).json({ error: 'Geçersiz akademi paket bilgileri.' });
    }

    try {
        const [[field]] = await pool.query('SELECT id, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [field_id]);
        if (!field) return res.status(404).json({ error: 'Saha bulunamadı veya kullanıma kapalı' });

        // Calculate next 4 weeks dates
        // schedule.day is 1 (Pazartesi) to 7 (Pazar)
        const reservationsToCreate = [];
        const today = new Date();
        // Zero out time
        today.setHours(0, 0, 0, 0);

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
                const dateStr = \`\${yyyy}-\${mm}-\${dd}\`;
                
                reservationsToCreate.push({
                    date: dateStr,
                    time_slot: targetTime,
                    duration: duration_hours
                });
            }
        }

        // Check if ANY of the computed dates are booked
        for (const reqRes of reservationsToCreate) {
            const [existing] = await pool.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')", [reqRes.date, field_id]);
            const requestedStart = minutes(reqRes.time_slot);
            const requestedEnd = requestedStart + reqRes.duration * 60;
            
            if (existing.some(r => requestedStart < minutes(r.time_slot) + Number(r.duration_hours) * 60 && requestedEnd > minutes(r.time_slot))) {
                return res.status(409).json({ error: \`\${reqRes.date} \${reqRes.time_slot} tarihi maalesef dolu. Lütfen farklı bir gün/saat programı seçin.\` });
            }
        }

        // Create all reservations
        // Let's divide package price by total sessions to distribute it, or just mark total_price = 0 and handle payment via package.
        // For simplicity, we just mark total_price as 0 and notes as 'Academy Package: ' + package_name
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_price, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'confirmed', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, 0, \`Abonelik: \${package_name}\`]
            );
        }

        res.json({ message: 'Abonelik başarıyla oluşturuldu ve takvime eklendi.', total_sessions: reservationsToCreate.length });

    } catch (e) {
        console.error('Academy reservation error:', e);
        res.status(500).json({ error: 'Sunucu hatası' });
    }
});
`;

if (!content.includes('/api/reservations/academy')) {
  // Insert before the last module.exports or at the end
  content = content.replace('app.post(\'/api/reservations\',', newEndpoint + '\napp.post(\'/api/reservations\',');
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Added backend endpoint');
} else {
  console.log('Backend endpoint already exists');
}
