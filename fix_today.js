const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

const regex = /        const today = new Date\(\);\n        \/\/ Zero out time\n        today.setHours\(0, 0, 0, 0\);/g;
content = content.replace(regex, '');

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed duplicate today declaration');
