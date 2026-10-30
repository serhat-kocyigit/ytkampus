const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

content = content.replace(
    /if \(text\.includes\('padel'\)\) return '[^']+';/,
    "if (text.includes('padel')) return 'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?q=80&w=900&auto=format&fit=crop';"
);

fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
console.log('Fixed Padel image to external court');
