const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Add bookingMode variable and update the logic
const oldSelectField = `    function selectField(id) {
      document.getElementById('field-select').value = id;
      document.getElementById('booking-catalog').style.display = 'none';
      document.getElementById('booking-detail').style.display = '';
      updateFieldDescription();
      loadSlots();
    }`;

const newSelectField = `    let bookingMode = 'hourly';
    
    function selectField(id) {
      document.getElementById('field-select').value = id;
      document.getElementById('booking-catalog').style.display = 'none';
      
      const field = window.allFields.find(f => f.id === id);
      
      if (bookingMode === 'academy') {
        document.getElementById('academy-packages').style.display = 'block';
        document.getElementById('academy-title-text').innerText = (field ? field.name : '') + ' Akademi & Abonelik Paketleri';
      } else {
        document.getElementById('booking-detail').style.display = '';
        updateFieldDescription();
        loadSlots();
      }
    }`;

content = content.replace(oldSelectField, newSelectField);

const oldShowHourly = `    function showHourlyBooking() {
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }`;

const newShowHourly = `    function showHourlyBooking() {
      bookingMode = 'hourly';
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }`;

content = content.replace(oldShowHourly, newShowHourly);

const oldShowAcademy = `    function showAcademyPackages() {
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'block';
    }`;

const newShowAcademy = `    function showAcademyPackages() {
      bookingMode = 'academy';
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block'; // First show fields!
    }`;

content = content.replace(oldShowAcademy, newShowAcademy);

// 2. Change the title in the academy packages HTML to have the id="academy-title-text"
content = content.replace('<h2 class="section-title">Tenis Akademi & Abonelik Paketleri</h2>', '<h2 class="section-title" id="academy-title-text">Akademi & Abonelik Paketleri</h2>');

// 3. Make back button on academy packages go back to field selection
content = content.replace('<button class="back-link" onclick="backToBookingType()" style="margin-bottom:15px;">← Seçim Ekranına Dön</button>', '<button class="back-link" onclick="showFieldCatalog()" style="margin-bottom:15px;">← Saha Seçimine Dön</button>');


fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed academy multi-field logic');
