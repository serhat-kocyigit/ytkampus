const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'js', 'app.js');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace(
    "formatDate: (d) => new Date(d).toLocaleDateString('tr-TR', { day: '2-digit', month: 'long', year: 'numeric' })",
    "formatDate: (d) => new Date(d).toLocaleDateString('tr-TR', { day: '2-digit', month: 'long', year: 'numeric', weekday: 'long' })"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Modified app.js date format');
