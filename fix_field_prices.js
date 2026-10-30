const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Replace renderFieldCatalog
content = content.replace(/function renderFieldCatalog\(\) \{[\s\S]*?\}\)\.join\(''\);\s*\}/, `function renderFieldCatalog() {
      const catalog = document.getElementById('field-catalog');
      if(!fields || !fields.length) return;
      catalog.innerHTML = fields.map(field => {
          const isSoon = field.name.toLowerCase().includes('padel') || field.name.toLowerCase().includes('havuz');
          const priceText = isSoon ? 'YAKINDA' : ProSaha.formatCurrency(field.price_per_hour) + '/saat';
          
          let priceHtml = '';
          if (bookingMode === 'hourly') {
            priceHtml = \`<span style="position:absolute; bottom:10px; right:10px; background:rgba(0,0,0,0.8); color:#FFD700; padding:4px 8px; border-radius:6px; font-weight:bold; font-size:12px; border:1px solid rgba(255,215,0,0.3);">\${priceText}</span>\`;
          } else if (isSoon) {
            priceHtml = \`<span style="position:absolute; bottom:10px; right:10px; background:rgba(0,0,0,0.8); color:#FFD700; padding:4px 8px; border-radius:6px; font-weight:bold; font-size:12px; border:1px solid rgba(255,215,0,0.3);">YAKINDA</span>\`;
          }

          return \`<button type="button" class="field-card-choice" \${isSoon ? 'disabled style="opacity:0.6; cursor:not-allowed;"' : \`onclick="selectField(\${field.id})"\`}>
          <div class="field-card-image" style="background-image:url('\${fieldImage(field)}')">
            <span class="field-card-type">\${field.name.replace('YT KAMPUS', '').trim()}</span>
            \${priceHtml}
          </div>
        </button>\`;
        }).join('');
    }`);

// Add renderFieldCatalog() to showHourlyBooking
content = content.replace(/function showHourlyBooking\(\) \{([\s\S]*?)bookingMode = 'hourly';/, `function showHourlyBooking() {\n      bookingMode = 'hourly';\n      renderFieldCatalog();`);

// Add renderFieldCatalog() to showAcademyPackages
content = content.replace(/function showAcademyPackages\(\) \{([\s\S]*?)bookingMode = 'academy';/, `function showAcademyPackages() {\n      bookingMode = 'academy';\n      renderFieldCatalog();`);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed field cards');
