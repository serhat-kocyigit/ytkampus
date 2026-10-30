const fs = require('fs');
let content = fs.readFileSync('./frontend/pages/auth/register.html', 'utf8');

const modalReplacement = `<div id="contract-modal" class="modal-overlay">
    <div class="modal-content">
      <span class="modal-close" onclick="closeModal('contract-modal')">&times;</span>
      <h3>INTER ACADEMY TÜRKİYE KAYSERİ FUTBOL OKULU VE ENTEGRE ÇALIŞAN KAYSERİ YETÜK SPOR KULÜBÜ ÜYELİK KAYIT VE TAAHHÜT METNİ</h3>
      <p><b>Saygıdeğer Üye Adayımız,</b></p>
      <p>KAYSERİ YETÜK Spor Kulübü ailesine hoş geldiniz! Kulübümüz, bireylerin fiziksel, zihinsel ve sosyal gelişimlerini desteklemeyi, spor ahlakını ve disiplinini ön planda tutarak geleceğin başarılı sporcularını ve sağlıklı bireylerini yetiştirmeyi amaçlamaktadır.</p>
      <p>Kulüp üyeliğinizin ve/veya velisi olduğunuz sporcumuzun kayıt işlemlerinin tamamlanabilmesi için lütfen aşağıdaki maddeleri dikkatlice okuyunuz ve onaylayınız.</p>
      
      <h4>1. Üyelik Şartları ve Genel Kurallar</h4>
      <ul>
        <li><b>Kulüp İlkelerine Uyum:</b> Üye (veya sporcu), antrenmanlarda, müsabakalarda ve kulüp faaliyetlerinde fair-play (dürüst oyun) kurallarına, antrenörlerin ve kulüp yönetiminin talimatlarına uymayı taahhüt eder.</li>
        <li><b>Tesis ve Ekipman Kullanımı:</b> Kulübe ait tesis, araç-gereç ve malzemelerin korunmasına özen gösterilmesi esastır. Kasıtlı veya ihmal sonucu doğacak zararlardan üye/veli sorumludur.</li>
        <li><b>Devamlılık ve Disiplin:</b> Sporcuların antrenman programlarına düzenli katılımı esastır. Geçerli bir mazereti olmaksızın devamsızlık yapan veya kulüp disiplinine aykırı davranan üyeler hakkında yönetim kurulu tarafından değerlendirme yapılır.</li>
      </ul>

      <h4>2. Mali Hükümler</h4>
      <ul>
        <li>Üyelik ve aidat ödemeleri, kulüp yönetiminin belirlediği [Aylık / Yıllık] periyotlarda ve ilan edilen tarihlerde düzenli olarak yapılmalıdır.</li>
        <li>Zamanında yapılmayan ödemeler kulübün işleyişini doğrudan etkilediğinden, ödeme takvimine hassasiyet gösterilmesi rica olunur.</li>
      </ul>

      <h4>3. Sağlık Beyanı</h4>
      <ul>
        <li>Kulübümüze kayıt yaptıran üye/sporcu, aktif spor yapmasına engel teşkil edecek herhangi bir kronik veya akut sağlık problemi bulunmadığını beyan eder.</li>
        <li><i>Not: Resmi müsabakalara katılım için ilgili hekimlerden alınacak "Spor Yapabilir" sağlık raporunun ibrazı zorunludur.</i></li>
      </ul>

      <h4>4. Kişisel Verilerin Korunması (KVKK) ve Medya İzinleri</h4>
      <ul>
        <li>Kulübümüz, üyelik formunda paylaştığınız kişisel verileri yasal mevzuata uygun olarak sadece kulüp içi iletişim, lisans işlemleri ve organizasyonlar için saklar.</li>
        <li>Kulüp faaliyetleri, antrenmanlar ve müsabakalar sırasında çekilen fotoğraf ve video görüntülerinin kulübün resmi sosyal medya hesaplarında ve tanıtım materyallerinde kullanılmasına izin verilmiş sayılır. (Özel bir durum varsa yönetime yazılı olarak bildirilmelidir).</li>
      </ul>

      <h4 style="margin-top: 20px;">BEYAN VE ONAY</h4>
      <p>INTER ACADEMY TÜRKİYE KAYSERİ FUTBOL OKULU VE ENTEGRE ÇALIŞAN KAYSERİ YETÜK SPOR KULÜBÜ’nün tüzüğünü, yukarıda belirtilen şartları, kural ve yükümlülükleri okudum, anladım. Kulübün bir üyesi / sporcu velisi olarak bu kurallara tam bir uyum göstereceğimi kabul, beyan ve taahhüt ederim.</p>
      <div style="background: var(--bg-800); padding: 16px; border-radius: 8px; margin-top: 16px;">
        <p style="margin: 0; font-size: 13px; color: var(--text-400);"><i>* Bu formu onaylayarak, yukarıdaki beyanları kendi adıma ve (varsa) velisi bulunduğum sporcu adına dijital olarak imzalamış ve taahhüt etmiş sayılıyorum.</i></p>
      </div>
    </div>
  </div>`;

content = content.replace(/<div id="contract-modal" class="modal-overlay">[\s\S]*?<\/div>\s*<\/div>/, modalReplacement);

fs.writeFileSync('./frontend/pages/auth/register.html', content, 'utf8');
console.log('register.html contract updated');
