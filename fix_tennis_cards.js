const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Fix pricing logic
const oldPricing = `       let amount = 8000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 2')) amount = 16000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 3')) amount = 24000;
       if(currentAcademyPackage.name.includes('2 Kişilik')) amount = 12000;
       if(currentAcademyPackage.name.includes('3 Kişilik')) amount = 10000;
       if(currentAcademyPackage.name.includes('Grup') && currentAcademyPackage.name.includes('Haftada 3')) amount = 12000;`;

const newPricing = `       let amount = 8000;
       if(currentAcademyPackage.name === 'Özel Ders') amount = 16000;
       if(currentAcademyPackage.name === 'Dans Özel Ders (Haftada 2)') amount = 16000;
       if(currentAcademyPackage.name === 'Dans Özel Ders (Haftada 3)') amount = 24000;
       if(currentAcademyPackage.name.includes('2 Kişilik')) amount = 12000;
       if(currentAcademyPackage.name.includes('3 Kişilik')) amount = 10000;
       if(currentAcademyPackage.name === 'Dans Grup (Haftada 3)') amount = 12000;
       if(currentAcademyPackage.name === 'Grup Eğitimi') amount = 8000;
       if(currentAcademyPackage.name === 'Çocuk Akademi') amount = 8000;`;

content = content.replace(oldPricing, newPricing);

// 2. Add prices to the tennis cards
// For 'Özel Ders'
content = content.replace(
  'Kişiye özel düzenli eğitim',
  'Kişiye özel düzenli eğitim<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık: 16.000 TL</span>'
);

// For '2 Kişilik'
content = content.replace(
  'İki kişilik düzenli eğitim',
  'İki kişilik düzenli eğitim<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 12.000 TL</span>'
);

// For '3 Kişilik'
content = content.replace(
  'Üç kişilik düzenli eğitim',
  'Üç kişilik düzenli eğitim<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 10.000 TL</span>'
);

// For 'Grup Eğitimi'
content = content.replace(
  '3-8 Kişilik grup eğitimleri',
  '3-8 Kişilik grup eğitimleri<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 8.000 TL</span>'
);

// For 'Çocuk Akademi'
content = content.replace(
  '<span style="display:block; margin-top:8px; font-size:13px;">(Belirlenen gün ve saatlerde 3-8 kişilik gruplar)</span>',
  '<span style="display:block; margin-top:8px; font-size:13px;">(Belirlenen gün ve saatlerde 3-8 kişilik gruplar)</span><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 8.000 TL</span>'
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed tennis pricing and cards');
