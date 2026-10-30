const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Replace allFields with fields
content = content.replace("if(!allFields.length)", "if(!fields || !fields.length)");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed ReferenceError');
