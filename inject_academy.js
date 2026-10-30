const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const injectionHtml = `
          <div id="booking-type-selection">
            <div class="section-header"><div><h2 class="section-title">Ne tür bir işlem yapmak istiyorsunuz?</h2><p style="font-size:13px;color:var(--text-500);margin-top:6px;">Lütfen aşağıdan bir seçenek belirleyin.</p></div></div>
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(300px, 1fr)); gap:20px; margin-top:20px;">
              <div onclick="showHourlyBooking()" style="cursor:pointer; background:#fff; border:2px solid transparent; box-shadow:0 2px 8px rgba(0,0,0,0.05); border-radius:12px; padding:30px; text-align:center; transition:0.2s;" onmouseover="this.style.borderColor='var(--brand-400)'" onmouseout="this.style.borderColor='transparent'">
                <div style="font-size:40px; margin-bottom:15px;">⏱️</div>
                <h3 style="margin:0 0 10px 0; color:var(--brand-600); font-size:20px;">Saatlik Kiralama</h3>
                <p style="margin:0; font-size:14px; color:var(--text-400); line-height:1.5;">Tek seferlik veya günübirlik saha kiralama işlemi yapın. İstediğiniz saatte maça başlayın.</p>
              </div>
              <div onclick="showAcademyPackages()" style="cursor:pointer; background:var(--brand-50); border:2px solid var(--brand-400); box-shadow:0 4px 15px rgba(22, 101, 52, 0.1); border-radius:12px; padding:30px; text-align:center; transition:0.2s;">
                <div style="font-size:40px; margin-bottom:15px;">🎾</div>
                <h3 style="margin:0 0 10px 0; color:var(--brand-600); font-size:20px;">Akademi & Abonelik</h3>
                <p style="margin:0; font-size:14px; color:var(--text-400); line-height:1.5;">Düzenli eğitim paketleri, çocuk akademisi ve özel tenis dersi üyeliklerinizi oluşturun.</p>
              </div>
            </div>
          </div>

          <div id="academy-packages" style="display:none">
            <button class="back-link" onclick="backToBookingType()" style="margin-bottom:15px;">← Seçim Ekranına Dön</button>
            <div class="section-header"><div><h2 class="section-title">Tenis Akademi & Abonelik Paketleri</h2><p style="font-size:13px;color:var(--text-500);margin-top:6px;">Size en uygun abonelik paketini seçerek rezervasyon talebinizi oluşturun.</p></div></div>
            
            <div style="display:grid; grid-template-columns:repeat(auto-fit, minmax(280px, 1fr)); gap:20px; margin-top:20px;">
              <!-- Özel Ders -->
              <div style="background:#000; color:#fff; border-radius:12px; overflow:hidden; display:flex; flex-direction:column;">
                <div style="background:#f59e0b; color:#000; padding:15px; text-align:center; font-weight:800; font-size:22px; letter-spacing:1px;">ÖZEL DERS</div>
                <div style="padding:20px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:600; margin-bottom:15px; line-height:1.6; color:#f59e0b;">HAFTADA 2<br>AYDA 8 SEANS<br>DİLEDİĞİNİZ GÜN VE SAATLERDE<br>DÜZENLİ EĞİTİM</p>
                  <div style="margin-top:15px;">
                    <div style="font-size:13px; color:#aaa;">SEANS ÜCRETİ: 2.000 TL</div>
                    <div style="font-size:24px; font-weight:700; margin-top:5px;">AYLIK 16.000 TL</div>
                  </div>
                </div>
                <button onclick="selectPackage('Özel Ders', 16000)" style="background:#f59e0b; color:#000; border:none; padding:15px; font-weight:700; cursor:pointer; width:100%;">BU PAKETİ SEÇ</button>
              </div>

              <!-- 2 Kişilik -->
              <div style="background:#000; color:#fff; border-radius:12px; overflow:hidden; display:flex; flex-direction:column;">
                <div style="background:#f59e0b; color:#000; padding:15px; text-align:center; font-weight:800; font-size:22px; letter-spacing:1px;">2 KİŞİLİK</div>
                <div style="padding:20px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:600; margin-bottom:15px; line-height:1.6; color:#f59e0b;">HAFTADA 2<br>AYDA 8 SEANS<br>DİLEDİĞİNİZ GÜN VE SAATLERDE<br>DÜZENLİ EĞİTİM</p>
                  <div style="margin-top:15px;">
                    <div style="font-size:13px; color:#aaa;">AYLIK KİŞİ BAŞI</div>
                    <div style="font-size:24px; font-weight:700; margin-top:5px;">12.000 TL</div>
                  </div>
                </div>
                <button onclick="selectPackage('2 Kişilik Grup', 12000)" style="background:#f59e0b; color:#000; border:none; padding:15px; font-weight:700; cursor:pointer; width:100%;">BU PAKETİ SEÇ</button>
              </div>

              <!-- 3 Kişilik -->
              <div style="background:#000; color:#fff; border-radius:12px; overflow:hidden; display:flex; flex-direction:column;">
                <div style="background:#f59e0b; color:#000; padding:15px; text-align:center; font-weight:800; font-size:22px; letter-spacing:1px;">3 KİŞİLİK</div>
                <div style="padding:20px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:600; margin-bottom:15px; line-height:1.6; color:#f59e0b;">HAFTADA 2<br>AYDA 8 SEANS<br>DİLEDİĞİNİZ GÜN VE SAATLERDE<br>DÜZENLİ EĞİTİM</p>
                  <div style="margin-top:15px;">
                    <div style="font-size:13px; color:#aaa;">AYLIK KİŞİ BAŞI</div>
                    <div style="font-size:24px; font-weight:700; margin-top:5px;">10.000 TL</div>
                  </div>
                </div>
                <button onclick="selectPackage('3 Kişilik Grup', 10000)" style="background:#f59e0b; color:#000; border:none; padding:15px; font-weight:700; cursor:pointer; width:100%;">BU PAKETİ SEÇ</button>
              </div>

              <!-- Grup -->
              <div style="background:#000; color:#fff; border-radius:12px; overflow:hidden; display:flex; flex-direction:column;">
                <div style="background:#f59e0b; color:#000; padding:15px; text-align:center; font-weight:800; font-size:22px; letter-spacing:1px;">GRUP</div>
                <div style="padding:20px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:600; margin-bottom:15px; line-height:1.6; color:#f59e0b;">HAFTADA 2<br>AYDA 8 SEANS<br>DİLEDİĞİNİZ GÜN VE SAATLERDE<br>3-8 KİŞİLİK GRUPLAR</p>
                  <div style="margin-top:15px;">
                    <div style="font-size:13px; color:#aaa;">AYLIK KİŞİ BAŞI</div>
                    <div style="font-size:24px; font-weight:700; margin-top:5px;">8.000 TL</div>
                  </div>
                </div>
                <button onclick="selectPackage('Grup Eğitimi', 8000)" style="background:#f59e0b; color:#000; border:none; padding:15px; font-weight:700; cursor:pointer; width:100%;">BU PAKETİ SEÇ</button>
              </div>

              <!-- Çocuk Akademi -->
              <div style="background:#fff; color:#000; border:2px solid #f59e0b; border-radius:12px; overflow:hidden; display:flex; flex-direction:column;">
                <div style="background:#f59e0b; color:#000; padding:15px; text-align:center; font-weight:800; font-size:22px; letter-spacing:1px;">ÇOCUK AKADEMİ</div>
                <div style="padding:20px; text-align:center; flex:1; display:flex; flex-direction:column; justify-content:center;">
                  <p style="font-weight:700; margin-bottom:15px; line-height:1.8; color:#333;">HAFTADA 2<br>AYDA 8 SEANS TENİS<br>8 SEANS İNGİLİZCE<br>4 SEANS DİYETİSYEN<br>TÜM AİLEYE DİYETİSYEN DESTEĞİ<br>BELİRLENEN GÜN SAATLERDE EĞİTİM<br>3-8 KİŞİLİK GRUPLAR</p>
                  <div style="margin-top:15px;">
                    <div style="font-size:13px; color:#777;">AYLIK KİŞİ BAŞI</div>
                    <div style="font-size:24px; font-weight:700; margin-top:5px; color:#000;">8.000 TL</div>
                  </div>
                </div>
                <button onclick="selectPackage('Çocuk Akademi', 8000)" style="background:#f59e0b; color:#000; border:none; padding:15px; font-weight:700; cursor:pointer; width:100%;">BU PAKETİ SEÇ</button>
              </div>

            </div>
          </div>

          <div id="booking-catalog" style="display:none">
            <button class="back-link" onclick="backToBookingType()" style="margin-bottom:15px;">← Seçim Ekranına Dön</button>`;

content = content.replace('<div id="booking-catalog">', injectionHtml);

const scriptInjection = `
    function showHourlyBooking() {
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }

    function showAcademyPackages() {
      document.getElementById('booking-type-selection').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'block';
    }

    function backToBookingType() {
      document.getElementById('booking-catalog').style.display = 'none';
      document.getElementById('booking-detail').style.display = 'none';
      document.getElementById('academy-packages').style.display = 'none';
      document.getElementById('booking-type-selection').style.display = 'block';
    }
    
    function showFieldCatalog() {
      document.getElementById('booking-detail').style.display = 'none';
      document.getElementById('booking-catalog').style.display = 'block';
    }

    function selectPackage(packageName, price) {
      ProSaha.toast(packageName + ' paketini seçtiniz. Yönetici onayı için başvuru ekranı hazırlanıyor...');
      // Gelecekte buraya form eklenebilir
    }
`;

content = content.replace('function showFieldCatalog() {', scriptInjection);

// Modify showPage('booking') to reset to type selection
const pageBookingMod = `
      if (name === 'booking') {
        backToBookingType();
        if(!allFields.length) loadFields();
      }`;
content = content.replace(`if (name === 'booking') { document.getElementById('booking-catalog').style.display='block'; document.getElementById('booking-detail').style.display='none'; if(!allFields.length) loadFields(); }`, pageBookingMod);


fs.writeFileSync(filePath, content, 'utf8');
console.log('Done');
