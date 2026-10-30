const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'admin', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace("res.data.map(f => <option value=\"${f.id}\">${f.name}</option>).join('')", "res.data.map(f => `<option value=\"${f.id}\">${f.name}</option>`).join('')");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed backticks');
