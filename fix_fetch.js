const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'mac-izle.html');
let content = fs.readFileSync(filePath, 'utf8');

const badFetch = `    ProSaha.fetch('/fields').then(res => { 
      if(res.ok) { 
        document.getElementById('match-field').innerHTML = res.data.map(f => \`<option value="\${f.id}">\${f.name}</option>\`).join(''); 
      } 
    });`;

const goodFetch = `    fetch('/api/fields').then(res => res.json()).then(data => { 
      document.getElementById('match-field').innerHTML = data.map(f => \`<option value="\${f.id}">\${f.name}</option>\`).join(''); 
    });`;

content = content.replace(badFetch, goodFetch);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed fetch');
