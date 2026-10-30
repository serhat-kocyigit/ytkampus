const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'mac-izle.html');
let content = fs.readFileSync(filePath, 'utf8');

// Insert dynamic fetch
const scriptInjection = `
    // Fetch dynamic fields
    ProSaha.fetch('/fields').then(res => { 
      if(res.ok) { 
        document.getElementById('match-field').innerHTML = res.data.map(f => \`<option value="\${f.id}">\${f.name}</option>\`).join(''); 
      } 
    });
`;

content = content.replace("// Populate times", scriptInjection + "\n    // Populate times");

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed mac-izle');
