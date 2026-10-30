const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

content = content.replace(
    /if \(text\.includes\('hal'\)\) return '[^']+';/,
    "if (text.includes('hal')) return '/assets/images/saha-7.jpeg';"
);

content = content.replace(
    /return 'https:\/\/images\.unsplash\.com\/photo-1551958219[^']+';/,
    "return '/assets/images/saha-7.jpeg';"
);

fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
console.log('Fixed Halı Saha 1 image with local saha-7');
