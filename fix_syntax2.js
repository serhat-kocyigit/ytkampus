const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace(/\\\`<button onclick="cancelRes\(\$\{r\.id\}\)" class="btn btn-danger btn-sm">.*?<\/button>\\\`/g, "'<button onclick=\"cancelRes(' + r.id + ')\" class=\"btn btn-danger btn-sm\">İptal Et</button>'");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed syntax error again');
