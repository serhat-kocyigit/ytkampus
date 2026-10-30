const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace(/window\.fields\.find/g, "fields.find");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed window.fields');
