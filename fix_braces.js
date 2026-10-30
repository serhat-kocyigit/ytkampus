const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const regex = /function showFieldCatalog\(\) \{ selectedSlot = null;\n      document\.getElementById\('booking-detail'\)\.style\.display = 'none';\n      document\.getElementById\('booking-catalog'\)\.style\.display = 'block';\n    \}\n\n[\s\S]*?let currentAcademyPackage = null;/;

const newCode = `function showFieldCatalog() { selectedSlot = null;
      document.getElementById('booking-detail').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }

    let currentAcademyPackage = null;`;

content = content.replace(regex, newCode);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed floating braces');
