const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

content = content.replace(
    /if \(text\.includes\('padel'\)\) return '[^']+';/,
    "if (text.includes('padel')) return '/assets/images/saha-11.jpeg';"
);

fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
console.log('Fixed Padel image to local');
