const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Skip conflict check if it's a dummy row
const oldConflictCheck = `        // Check if ANY of the computed dates are booked
        for (const reqRes of reservationsToCreate) {
            const [existing] = await pool.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')", [reqRes.date, field_id]);
            const requestedStart = minutes(reqRes.time_slot);
            const requestedEnd = requestedStart + reqRes.duration * 60;
            
            if (existing.some(r => requestedStart < minutes(r.time_slot) + Number(r.duration_hours) * 60 && requestedEnd > minutes(r.time_slot))) {
                return res.status(409).json({ error: \`\${reqRes.date} \${reqRes.time_slot} tarihi maalesef dolu. Lütfen farklı bir gün/saat programı seçin.\` });
            }
        }`;

const newConflictCheck = `        // Check if ANY of the computed dates are booked (except dummy rows)
        if (schedule.length > 0) {
            for (const reqRes of reservationsToCreate) {
                const [existing] = await pool.query("SELECT time_slot, duration_hours FROM reservations WHERE date = ? AND field_id = ? AND status IN ('pending', 'confirmed')", [reqRes.date, field_id]);
                const requestedStart = minutes(reqRes.time_slot);
                const requestedEnd = requestedStart + reqRes.duration * 60;
                
                if (existing.some(r => requestedStart < minutes(r.time_slot) + Number(r.duration_hours) * 60 && requestedEnd > minutes(r.time_slot))) {
                    return res.status(409).json({ error: \`\${reqRes.date} \${reqRes.time_slot} tarihi maalesef dolu. Lütfen farklı bir gün/saat programı seçin.\` });
                }
            }
        }`;

content = content.replace(oldConflictCheck, newConflictCheck);

// 2. Fix the insert logic to use 'pending' and groupId
// Let's use substring replacement securely

const startIdx = content.indexOf('// Create all reservations');
const endIdx = content.indexOf("res.json({ message: 'Abonelik", startIdx);

if (startIdx > -1 && endIdx > -1) {
    const newInsertLogic = `// Create all reservations
        const groupId = Date.now().toString();
        for (const reqRes of reservationsToCreate) {
             await pool.query(
                "INSERT INTO reservations (user_id, field_id, date, time_slot, duration_hours, total_amount, status, notes) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)",
                [req.user.id, field_id, reqRes.date, reqRes.time_slot, reqRes.duration, 0, \`Abonelik: \${package_name} | group: \${groupId}\`]
            );
        }

        res.json({ success: true, message: 'Abonelik başarıyla oluşturuldu.', group_id: groupId, total_sessions: reservationsToCreate.length });
    } catch (e) {`;

    // Wait, the end line might be a bit different, let's just find the closing bracket of the try block.
    // I will replace everything from startIdx to the line before `catch`
    
    // Actually, let's just do a manual string replace:
}

fs.writeFileSync(filePath, content, 'utf8');
console.log('Skipped dummy conflict check');
