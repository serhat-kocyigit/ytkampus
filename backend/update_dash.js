const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/user/dashboard.html', 'utf8');

const oldImageFunc = /function fieldImage\(field\) \{[\s\S]*?return 'https:\/\/images\.unsplash\.com\/[^;]+;\n      \}/;
const newImageFunc = `function fieldImage(field) {
        const text = field.name.toLowerCase();
        if (text.includes('inter halısaha')) return '/assets/images/saha-7.jpeg';
        if (text.includes('halı saha')) return '/assets/images/saha-14.jpeg';
        if (text.includes('tenis')) return '/assets/images/saha-25.jpeg';
        if (text.includes('voleybol')) return '/assets/images/saha-5.jpeg';
        if (text.includes('basketbol')) return '/assets/images/saha-6.jpeg';
        if (text.includes('dans')) return '/assets/images/saha-24.jpeg';
        if (text.includes('sanat')) return '/assets/images/saha-23.jpeg';
        if (text.includes('müzik')) return '/assets/images/saha-26.jpeg';
        if (text.includes('padel')) return '/assets/images/saha-11.jpeg';
        if (text.includes('havuz')) return '/assets/images/saha-15.jpeg';
        return '/assets/images/saha-1.jpeg';
      }`;

content = content.replace(oldImageFunc, newImageFunc);

const oldRender = /catalog\.innerHTML = fields\.map\(field => `[\s\S]*?`\)\.join\(''\);/;
const newRender = `catalog.innerHTML = fields.map(field => {
          const isSoon = field.name.toLowerCase().includes('padel') || field.name.toLowerCase().includes('havuz');
          const priceText = isSoon ? 'YAKINDA' : ProSaha.formatCurrency(field.price_per_hour) + '/saat';
          return \`<button type="button" class="field-card-choice" \${isSoon ? 'disabled style="opacity:0.6; cursor:not-allowed;"' : \`onclick="selectField(\${field.id})"\`}>
          <div class="field-card-image" style="background-image:url('\${fieldImage(field)}')">
            <span class="field-card-type">\${field.name.replace('YT KAMPUS', '').trim()}</span>
            <span style="position:absolute; bottom:10px; right:10px; background:rgba(0,0,0,0.8); color:#FFD700; padding:4px 8px; border-radius:6px; font-weight:bold; font-size:12px; border:1px solid rgba(255,215,0,0.3);">\${priceText}</span>
          </div>
        </button>\`;
        }).join('');`;

content = content.replace(oldRender, newRender);
fs.writeFileSync('./frontend/pages/user/dashboard.html', content, 'utf8');
console.log('Dashboard updated!');
