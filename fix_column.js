const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'backend', 'server.js');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace("total_price, status, notes) VALUES", "total_amount, status, notes) VALUES");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed column name');
