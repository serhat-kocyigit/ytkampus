const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// Dans Özel Ders (Haftada 2)
content = content.replace(
  'Ayda 8 Seans<br>Dilediğiniz gün ve saatlerde',
  'Ayda 8 Seans<br>Dilediğiniz gün ve saatlerde<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık: 16.000 TL</span>'
);

// Dans Özel Ders (Haftada 3)
content = content.replace(
  'Ayda 12 Seans<br>Dilediğiniz gün ve saatlerde',
  'Ayda 12 Seans<br>Dilediğiniz gün ve saatlerde<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık: 24.000 TL</span>'
);

// Dans Grup (Haftada 2)
content = content.replace(
  'Ayda 8 Seans (3-12 Kişilik Gruplar)<br>Belirlenen gün ve saatlerde',
  'Ayda 8 Seans (3-12 Kişilik Gruplar)<br>Belirlenen gün ve saatlerde<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 8.000 TL</span>'
);

// Dans Grup (Haftada 3)
content = content.replace(
  'Ayda 12 Seans (3-12 Kişilik Gruplar)<br>Belirlenen gün ve saatlerde',
  'Ayda 12 Seans (3-12 Kişilik Gruplar)<br>Belirlenen gün ve saatlerde<br><br><span style="color:var(--brand-600); font-size:16px; font-weight:700;">Aylık Kişi Başı: 12.000 TL</span>'
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed dance prices');
