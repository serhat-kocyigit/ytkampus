const fs = require('fs');
let content = fs.readFileSync('./frontend/index.html', 'utf8');

const startIndex = content.indexOf('<!-- CTA -->');
const endIndex = content.indexOf('<!-- LIGHTBOX MODAL -->');

const replacement = `<!-- CTA & İLETİŞİM -->
  <div id="iletisim" class="cta-section">
    <h2>İletişim & <span class="gradient-text-gold">Ulaşım</span></h2>
    <p>Sanat ve sporla dolu ayrıcalıklı bir yaşama adım atmak için YT Kampüs ailesine katılın. Tesisimizi ziyaret edin!</p>
    
    <div style="display:flex; flex-wrap:wrap; gap:20px; justify-content:center; margin-top:32px; margin-bottom: 32px;">
      <!-- İletişim Kartı -->
      <div style="background:rgba(255,255,255,0.1); padding:24px; border-radius:16px; backdrop-filter:blur(10px); border:1px solid rgba(255,255,255,0.2); min-width:260px; text-align:left;">
        <h3 style="font-size:20px; margin-bottom:12px; color:#fff;">📞 İletişim Bilgileri</h3>
        <p style="margin:0 0 8px 0; font-size:15px; color:rgba(255,255,255,0.8);"><strong>Tel:</strong> <a href="tel:+905550000000" style="color:rgba(255,255,255,0.8); text-decoration:none;">0 (555) 000 00 00</a></p>
        <p style="margin:0; font-size:15px; color:rgba(255,255,255,0.8);"><strong>E-Posta:</strong> <a href="mailto:iletisim@ytkampus.com" style="color:rgba(255,255,255,0.8); text-decoration:none;">iletisim@ytkampus.com</a></p>
      </div>
      
      <!-- Konum Kartı -->
      <div style="background:rgba(255,255,255,0.1); padding:24px; border-radius:16px; backdrop-filter:blur(10px); border:1px solid rgba(255,255,255,0.2); min-width:260px; text-align:left;">
        <h3 style="font-size:20px; margin-bottom:12px; color:#fff;">📍 Adres & Konum</h3>
        <p style="margin:0; font-size:15px; color:rgba(255,255,255,0.8); line-height:1.5;">Kayseri, Türkiye<br>YT Kampüs & Inter Academy</p>
        <a href="https://maps.app.goo.gl/3ea84B6T5ei7FhRp8" target="_blank" style="display:inline-block; margin-top:12px; color:#FFD700; text-decoration:underline; font-weight:700; font-size:15px;">Haritada Görüntüle ↗</a>
      </div>
    </div>

    <div class="cta-buttons">
      <a href="/pages/auth/register.html" class="btn btn-light btn-lg">Online Kayıt & Rezervasyon</a>
      <a href="https://maps.app.goo.gl/3ea84B6T5ei7FhRp8" target="_blank" class="btn btn-outline-light btn-lg">Yol Tarifi Al</a>
    </div>
  </div>

  <!-- FOOTER -->
  <footer>
    <div class="logo-container" style="gap:10px;">
      <img src="assets/images/saha-27.jpeg" alt="YT Kampüs Logosu" style="height:32px; mix-blend-mode:multiply;">
      <div class="logo-text" style="font-size:18px;">YT<span>Kampüs</span></div>
    </div>
    <div>© 2026 YT Kampüs Merkezi. Tüm Hakları Saklıdır.</div>
    <div style="display:flex; gap:24px;">
      <a href="#">Gizlilik Politikası</a>
      <a href="#">Kullanım Şartları</a>
      <a href="#iletisim">İletişim</a>
    </div>
  </footer>

  `;

content = content.substring(0, startIndex) + replacement + content.substring(endIndex);

fs.writeFileSync('./frontend/index.html', content, 'utf8');
console.log('Done replacement');
