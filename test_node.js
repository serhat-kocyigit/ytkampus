const fs = require('fs');
let c = fs.readFileSync('frontend/pages/admin/dashboard.html', 'utf8');

const oldStr = 'html += `<div style="min-height:80px;';
const newStr = 'html += `<div onclick="openDayModal(\\'${dateStr}\\')" style="cursor:pointer; min-height:80px;';
c = c.replace(oldStr, newStr);

fs.writeFileSync('frontend/pages/admin/dashboard.html', c);
