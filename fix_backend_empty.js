const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

const regex = /if \(\!field_id \|\| \!package_name \|\| \!schedule \|\| \!Array.isArray\(schedule\)\) \{[\s\S]*?const reservationsToCreate = \[\];/;

const newCode = `if (!field_id || !package_name || !schedule || !Array.isArray(schedule)) {
       return res.status(400).json({ error: 'Geçersiz akademi paket bilgileri.' });
    }

    try {
        const [[field]] = await pool.query('SELECT id, price_per_hour FROM fields WHERE id = ? AND is_active = 1', [field_id]);
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
                date: \`\${yyyy}-\${mm}-\${dd}\`,
                time_slot: '09:00', // dummy
                duration: duration_hours
            });
        }`;

content = content.replace(regex, newCode);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed backend empty schedule');
