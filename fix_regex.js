const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Use a simpler string match or regex to bypass line endings
content = content.replace(/function selectField\(id\) \{[\s\S]*?loadSlots\(\);\s*\}/, `let bookingMode = 'hourly';
    
    function selectField(id) {
      document.getElementById('field-select').value = id;
      document.getElementById('booking-catalog').style.display = 'none';
      
      const field = fields.find(f => f.id === id); // NOTE: using fields instead of window.allFields
      
      if (bookingMode === 'academy') {
        document.getElementById('academy-packages').style.display = 'block';
        document.getElementById('academy-title-text').innerText = (field ? field.name : '') + ' Akademi & Abonelik Paketleri';
      } else {
        document.getElementById('booking-detail').style.display = '';
        updateFieldDescription();
        loadSlots();
      }
    }`);

content = content.replace(/function showHourlyBooking\(\) \{[\s\S]*?display = 'block';\s*\}/, `function showHourlyBooking() {
      bookingMode = 'hourly';
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }`);

content = content.replace(/function showAcademyPackages\(\) \{[\s\S]*?display = 'block';\s*\}/, `function showAcademyPackages() {
      bookingMode = 'academy';
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }`);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed replacements');
