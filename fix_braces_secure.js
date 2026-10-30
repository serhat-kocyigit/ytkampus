const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const markerStart = "function showFieldCatalog() { selectedSlot = null;";
const startIdx = content.indexOf(markerStart);

const markerEnd = "let currentAcademyPackage = null;";
// find the first occurrence of markerEnd AFTER markerStart
const endIdx = content.indexOf(markerEnd, startIdx);

if (startIdx !== -1 && endIdx !== -1) {
    const cleanStr = `function showFieldCatalog() { selectedSlot = null;
      document.getElementById('booking-detail').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }

    `;
    content = content.substring(0, startIdx) + cleanStr + content.substring(endIdx);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Successfully removed orphaned code block!');
} else {
    console.log('Markers not found');
}
