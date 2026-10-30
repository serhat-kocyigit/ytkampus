const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Replace ProSaha.formatDate with native formatter inside renderMyList
content = content.replace(
    /\$\{ProSaha\.formatDate\(r\.date\)\}/g,
    "${new Date(r.date).toLocaleDateString('tr-TR', { day: '2-digit', month: 'long', year: 'numeric', weekday: 'long' })}"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed date format in HTML directly');
