const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// Replace the insert loop in academy to put total_amount on ALL rows
const oldInsert = `        const groupId = Date.now().toString();
        let isFirst = true;
        for (const reqRes of reservationsToCreate) {
             const amt = isFirst ? Number(total_amount) : 0;
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, amt, \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
             isFirst = false;
        }`;

const newInsert = `        const groupId = Date.now().toString();
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, Number(total_amount), \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
        }`;

content = content.replace(oldInsert, newInsert);
fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed backend to charge full amount on all rows');
