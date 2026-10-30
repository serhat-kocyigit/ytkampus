const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// There are two async function proceedToAcademyPayment blocks now.
// Let's find the last one and remove it.
const lines = content.split('\\n');
let startIdx = -1;
let endIdx = -1;

for (let i = lines.length - 1; i >= 0; i--) {
  if (lines[i].includes('async function proceedToAcademyPayment() {')) {
     startIdx = i;
     // find the end
     for (let j = i; j < lines.length; j++) {
       if (lines[j].includes('function updateFieldDescription() {')) {
          endIdx = j - 1;
          break;
       }
     }
     break;
  }
}

if (startIdx !== -1 && endIdx !== -1) {
   lines.splice(startIdx, endIdx - startIdx);
   fs.writeFileSync(filePath, lines.join('\\n'), 'utf8');
   console.log('Removed duplicate proceed function');
} else {
   console.log('Could not find duplicate');
}
