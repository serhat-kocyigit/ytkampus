const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Modify showPage('booking') to reset to type selection
content = content.replace("if (name === 'booking') showFieldCatalog();", "if (name === 'booking') { backToBookingType(); if(!allFields.length) loadFields(); }");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Done replacement');
