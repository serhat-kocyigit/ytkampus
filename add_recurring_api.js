const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

const newEndpoint = `
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
        const endStr = \`\${yyyy}-\${mm}-\${dd}\`;

        const [reservations] = await pool.query(
            "SELECT date, time_slot, duration_hours FROM reservations WHERE field_id = ? AND date >= CURRENT_DATE AND date <= ? AND status IN ('pending', 'confirmed')",
            [field_id, endStr]
        );

        // We want to return a 7-day grid (Mon-Sun), from 09:00 to 23:00.
        // A slot is "available" if it is free on ALL 4 occurrences of that day in the next 28 days.
        const grid = {};
        for(let d=1; d<=7; d++) grid[d] = {}; // 1: Monday, 7: Sunday

        const SLOT_HOURS = Array.from({length: 15}, (_,i) => String(i+9).padStart(2, '0') + ':00');
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
                    const cStr = \`\${c_yyyy}-\${c_mm}-\${c_dd}\`;

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
`;

if (!content.includes('/api/slots/recurring')) {
  content = content.replace('app.get(\'/api/reservations/my\',', newEndpoint + '\napp.get(\'/api/reservations/my\',');
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Added recurring slots API');
} else {
  console.log('Recurring slots API already exists');
}
