const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Extract total_amount from req.body
const oldRoute = `app.post('/api/reservations/academy', auth, async (req, res) => {
    const { field_id, package_name, schedule, duration_hours = 1 } = req.body;`;

const newRoute = `app.post('/api/reservations/academy', auth, async (req, res) => {
    const { field_id, package_name, schedule, duration_hours = 1, total_amount = 0 } = req.body;`;

content = content.replace(oldRoute, newRoute);

// 2. Divide total_amount by reservationsToCreate.length and use it in INSERT
const oldInsert = `        const groupId = Date.now().toString();
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, 0, \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
        }`;

const newInsert = `        const groupId = Date.now().toString();
        const sessionAmount = Number(total_amount) / (reservationsToCreate.length || 1);
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, sessionAmount, \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
        }`;

content = content.replace(oldInsert, newInsert);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed total_amount in backend');
