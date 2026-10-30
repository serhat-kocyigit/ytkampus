const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const regex = /<div style="display:grid; grid-template-columns:repeat\(auto-fit, minmax\(280px, 1fr\)\); gap:20px; margin-top:20px;">[\s\S]*?<!-- \/Çocuk Akademi -->\s*<\/div>\s*<\/div>/;

// Wait, my previous code didn't have <!-- /Çocuk Akademi -->. Let's match until `</div>\n          </div>\n\n          <div id="booking-catalog"`

const startMarker = '<div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:20px; margin-top:20px;">';
const endMarker = '<div id="booking-catalog" style="display:none">';

const startIndex = content.indexOf(startMarker);
const endIndex = content.indexOf(endMarker);

if (startIndex !== -1 && endIndex !== -1) {
  const newHtml = `<div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(240px, 1fr)); gap:20px; margin-top:20px; padding-bottom:30px;">
              <!-- Özel Ders -->
              <div style="background:#fff; border:1px solid var(--border); border-radius:12px; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 4px 15px rgba(0,0,0,0.03); transition:0.2s;">
                <div style="background:var(--bg-card); border-bottom:1px solid var(--border); color:var(--brand-600); padding:16px; text-align:center; font-weight:700; font-size:18px;">ÖZEL DERS</div>
                <div style="padding:24px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:500; margin:0; line-height:1.8; color:var(--text-400); font-size:14px;">
                    <span style="display:block; color:var(--text-900); font-weight:600; margin-bottom:8px;">Haftada 2 Gün / Ayda 8 Seans</span>
                    Dilediğiniz gün ve saatlerde<br>Kişiye özel düzenli eğitim
                  </p>
                </div>
                <div style="padding:16px; border-top:1px solid var(--border); background:#fafafa;">
                  <button onclick="selectPackage('Özel Ders', 0)" class="btn btn-primary" style="width:100%; font-weight:600;">BU PAKETİ SEÇ</button>
                </div>
              </div>

              <!-- 2 Kişilik -->
              <div style="background:#fff; border:1px solid var(--border); border-radius:12px; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 4px 15px rgba(0,0,0,0.03); transition:0.2s;">
                <div style="background:var(--bg-card); border-bottom:1px solid var(--border); color:var(--brand-600); padding:16px; text-align:center; font-weight:700; font-size:18px;">2 KİŞİLİK</div>
                <div style="padding:24px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:500; margin:0; line-height:1.8; color:var(--text-400); font-size:14px;">
                    <span style="display:block; color:var(--text-900); font-weight:600; margin-bottom:8px;">Haftada 2 Gün / Ayda 8 Seans</span>
                    Dilediğiniz gün ve saatlerde<br>İki kişilik düzenli eğitim
                  </p>
                </div>
                <div style="padding:16px; border-top:1px solid var(--border); background:#fafafa;">
                  <button onclick="selectPackage('2 Kişilik Grup', 0)" class="btn btn-primary" style="width:100%; font-weight:600;">BU PAKETİ SEÇ</button>
                </div>
              </div>

              <!-- 3 Kişilik -->
              <div style="background:#fff; border:1px solid var(--border); border-radius:12px; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 4px 15px rgba(0,0,0,0.03); transition:0.2s;">
                <div style="background:var(--bg-card); border-bottom:1px solid var(--border); color:var(--brand-600); padding:16px; text-align:center; font-weight:700; font-size:18px;">3 KİŞİLİK</div>
                <div style="padding:24px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:500; margin:0; line-height:1.8; color:var(--text-400); font-size:14px;">
                    <span style="display:block; color:var(--text-900); font-weight:600; margin-bottom:8px;">Haftada 2 Gün / Ayda 8 Seans</span>
                    Dilediğiniz gün ve saatlerde<br>Üç kişilik düzenli eğitim
                  </p>
                </div>
                <div style="padding:16px; border-top:1px solid var(--border); background:#fafafa;">
                  <button onclick="selectPackage('3 Kişilik Grup', 0)" class="btn btn-primary" style="width:100%; font-weight:600;">BU PAKETİ SEÇ</button>
                </div>
              </div>

              <!-- Grup -->
              <div style="background:#fff; border:1px solid var(--border); border-radius:12px; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 4px 15px rgba(0,0,0,0.03); transition:0.2s;">
                <div style="background:var(--bg-card); border-bottom:1px solid var(--border); color:var(--brand-600); padding:16px; text-align:center; font-weight:700; font-size:18px;">GRUP EĞİTİMİ</div>
                <div style="padding:24px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:500; margin:0; line-height:1.8; color:var(--text-400); font-size:14px;">
                    <span style="display:block; color:var(--text-900); font-weight:600; margin-bottom:8px;">Haftada 2 Gün / Ayda 8 Seans</span>
                    Belirlenen gün ve saatlerde<br>3-8 Kişilik grup eğitimleri
                  </p>
                </div>
                <div style="padding:16px; border-top:1px solid var(--border); background:#fafafa;">
                  <button onclick="selectPackage('Grup Eğitimi', 0)" class="btn btn-primary" style="width:100%; font-weight:600;">BU PAKETİ SEÇ</button>
                </div>
              </div>

              <!-- Çocuk Akademi -->
              <div style="background:var(--brand-50); border:1px solid var(--brand-300); border-radius:12px; overflow:hidden; display:flex; flex-direction:column; box-shadow:0 4px 15px rgba(22,101,52,0.08); transition:0.2s; grid-column: 1 / -1; max-width:600px; margin:0 auto; width:100%;">
                <div style="background:var(--brand-500); color:#fff; padding:16px; text-align:center; font-weight:700; font-size:18px;">ÇOCUK AKADEMİ (KAPSAMLI)</div>
                <div style="padding:24px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:500; margin:0; line-height:1.8; color:var(--text-500); font-size:14px;">
                    <span style="display:block; color:var(--brand-600); font-weight:700; margin-bottom:12px; font-size:15px;">Haftada 2 Gün / Ayda 8 Seans Spor Eğitimi</span>
                    <strong>Ekstra Hizmetler:</strong><br>
                    Ayda 8 Seans İngilizce Eğitimi<br>
                    Ayda 4 Seans Diyetisyen Kontrolü<br>
                    Tüm Aileye Diyetisyen Desteği<br>
                    <span style="display:block; margin-top:8px; font-size:13px;">(Belirlenen gün ve saatlerde 3-8 kişilik gruplar)</span>
                  </p>
                </div>
                <div style="padding:16px; border-top:1px solid var(--brand-200); background:#fff;">
                  <button onclick="selectPackage('Çocuk Akademi', 0)" class="btn btn-primary" style="width:100%; font-weight:600;">BU PAKETİ SEÇ</button>
                </div>
              </div>

            </div>
          </div>

          `;
  
  content = content.substring(0, startIndex) + newHtml + content.substring(endIndex);
  fs.writeFileSync(filePath, content, 'utf8');
  console.log('Fixed cards design');
} else {
  console.log('Markers not found');
}
