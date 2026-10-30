const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// Replace the insert loop
const searchStr = `        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'confirmed', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, 0, \`Abonelik: \${package_name}\`]
            );
        }

        res.json({ message: 'Abonelik başarıyla oluşturuldu ve takvime eklendi.', total_sessions: reservationsToCreate.length });`;

const replacement = `        const groupId = Date.now().toString();
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, 0, \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
        }

        res.json({ success: true, message: 'Abonelik rezervasyonları oluşturuldu.', group_id: groupId, total_sessions: reservationsToCreate.length });`;

if (content.includes(searchStr)) {
    content = content.replace(searchStr, replacement);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Fixed insert logic successfully');
} else {
    console.log('Search string not found!');
}
