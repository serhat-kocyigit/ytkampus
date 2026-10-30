const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Replace the literal \` with just an apostrophe or single quotes.
// Let's just avoid nested backticks by using single quotes for the button HTML!
const searchStr = "<td>${r.status === 'confirmed' ? \\`<button onclick=\"cancelRes(${r.id})\" class=\"btn btn-danger btn-sm\">İptal Et</button>\\` : '-'}</td>";
const newStr = "<td>${r.status === 'confirmed' ? '<button onclick=\"cancelRes(' + r.id + ')\" class=\"btn btn-danger btn-sm\">İptal Et</button>' : '-'}</td>";

// But wait, there are utf8 issues with "İptal". Let's match more carefully or just replace the specific backslash-backtick combo.
content = content.replace(/\\\`<button onclick="cancelRes\(\$\{r\.id\}\)" class="btn btn-danger btn-sm">.*?<\/button>\\\`/g, "'<button onclick=\"cancelRes(' + r.id + ')\" class=\"btn btn-danger btn-sm\">İptal Et</button>'");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed syntax error');
