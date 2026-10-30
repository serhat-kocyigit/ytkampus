const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Fix the modal CSS
const oldModalRegex = /<div id="academy-schedule-modal" class="modal" style="display:none;">[\s\S]*?<\/div>\s*<\/div>/;
const newModalHtml = `
    <!-- Academy Schedule Modal -->
    <div id="academy-schedule-modal" style="display:none; position:fixed; top:0; left:0; width:100%; height:100%; background:rgba(0,0,0,0.6); z-index:9999; align-items:center; justify-content:center; padding:20px;">
      <div style="background:#fff; border-radius:12px; width:100%; max-width:500px; padding:30px; box-shadow:0 10px 30px rgba(0,0,0,0.2); position:relative; max-height:90vh; overflow-y:auto;">
        <span onclick="document.getElementById('academy-schedule-modal').style.display='none'" style="position:absolute; top:15px; right:20px; font-size:24px; cursor:pointer; color:#999;">&times;</span>
        <h2 id="academy-schedule-title" style="margin-top:0; margin-bottom:10px; color:var(--brand-600); font-size:22px;">Paket Gün & Saat Seçimi</h2>
        <p style="color:var(--text-500); font-size:14px; margin-bottom:20px; line-height:1.5;">Lütfen haftalık düzenli dersleriniz için uygun gün ve saatleri belirleyin. Sistem bu saatleri kontrol edip 1 ay (4 hafta) boyunca sizin için rezerve edecektir.</p>
        
        <div id="academy-schedule-inputs"></div>
        
        <div style="margin-top:20px; display:flex; justify-content:flex-end; gap:10px;">
          <button type="button" class="btn btn-secondary" onclick="document.getElementById('academy-schedule-modal').style.display='none'">İptal</button>
          <button type="button" class="btn btn-primary" onclick="proceedToAcademyPayment()">Programı Onayla ve Öde</button>
        </div>
      </div>
    </div>
`;
content = content.replace(oldModalRegex, newModalHtml);


// 2. Update selectPackage calls in HTML to include duration_hours
// Note: Only Dans Özel Ders (Haftada 3) needs 3 hours. Let's make Dans Özel Ders (Haftada 2) 2 hours!
// And others 1 hour.
content = content.replace(/selectPackage\('Özel Ders', 2\)/g, "selectPackage('Özel Ders', 2, 1)");
content = content.replace(/selectPackage\('2 Kişilik Grup', 2\)/g, "selectPackage('2 Kişilik Grup', 2, 1)");
content = content.replace(/selectPackage\('3 Kişilik Grup', 2\)/g, "selectPackage('3 Kişilik Grup', 2, 1)");
content = content.replace(/selectPackage\('Çocuk Akademi', 0\)/g, "selectPackage('Çocuk Akademi', 0, 1)"); // fixed days

content = content.replace(/selectPackage\('Dans Özel Ders \(Haftada 2\)', 2\)/g, "selectPackage('Dans Özel Ders (Haftada 2)', 2, 2)");
content = content.replace(/selectPackage\('Dans Özel Ders \(Haftada 3\)', 3\)/g, "selectPackage('Dans Özel Ders (Haftada 3)', 3, 3)");

content = content.replace(/selectPackage\('Dans Grup \(Haftada 2\)', 0\)/g, "selectPackage('Dans Grup (Haftada 2)', 0, 2)");
content = content.replace(/selectPackage\('Dans Grup \(Haftada 3\)', 0\)/g, "selectPackage('Dans Grup (Haftada 3)', 0, 3)");

// 3. Rewrite selectPackage and proceed function
const oldJS = /let currentAcademyPackage = null;[\s\S]*?\}\s*\}/;
const newJS = `let currentAcademyPackage = null;
    function selectPackage(packageName, frequency, durationHours = 1) {
      const fieldId = document.getElementById('field-select').value;
      const field = window.fields.find(f => f.id == fieldId);
      currentAcademyPackage = { name: packageName, frequency: frequency, duration: durationHours, field_id: fieldId, field_name: field ? field.name : '' };
      
      if (frequency > 0) {
        let html = '';
        const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
        for(let i=1; i<=frequency; i++) {
           html += \`
             <div class="form-group" style="background:#f9f9f9; border:1px solid var(--border); padding:15px; border-radius:8px; margin-bottom:15px;">
               <label style="color:var(--text-900); font-weight:600; font-size:14px; display:block; margin-bottom:10px;">\${i}. Gün ve Saat Seçimi</label>
               <div style="display:flex; gap:10px;">
                 <select id="acad-day-\${i}" class="input-field" style="flex:1; margin-bottom:0;">
                   \${days.map((d, idx) => \`<option value="\${idx+1}">\${d}</option>\`).join('')}
                 </select>
                 <select id="acad-time-\${i}" class="input-field" style="flex:1; margin-bottom:0;">
                   \${Array.from({length:15}, (_,i)=>i+9).map(h => \`<option value="\${String(h).padStart(2,'0')}:00">\${String(h).padStart(2,'0')}:00</option>\`).join('')}
                 </select>
               </div>
             </div>
           \`;
        }
        document.getElementById('academy-schedule-inputs').innerHTML = html;
        document.getElementById('academy-schedule-modal').style.display = 'flex';
      } else {
        ProSaha.toast('Bu pakette (Grup/Akademi) gün ve saatler tesis tarafından belirlenmektedir. Kaydınız alınıyor, size gün ve saat bilgisi verilecektir.', 'info');
        
        // Directly call backend to register them without scheduling specific days.
        setTimeout(() => {
             proceedToAcademyPayment(true);
        }, 3000);
      }
    }

    async function proceedToAcademyPayment(isGroup = false) {
       const selected = [];
       if (!isGroup) {
           for(let i=1; i<=currentAcademyPackage.frequency; i++) {
              selected.push({
                 day: document.getElementById('acad-day-'+i).value,
                 time: document.getElementById('acad-time-'+i).value
              });
           }
       } else {
           // Provide a dummy schedule or handle in backend.
           // For group, maybe just schedule on Sunday 12:00 as placeholder or let backend handle empty array.
           // Since backend expects an array, let's pass empty array.
       }
       
       let btn;
       if (!isGroup) {
           btn = document.querySelector('#academy-schedule-modal .btn-primary');
           if (btn) { btn.innerText = 'Kontrol Ediliyor...'; btn.disabled = true; }
       }

       const { ok, data } = await ProSaha.fetch('/reservations/academy', {
         method: 'POST',
         body: JSON.stringify({
            field_id: currentAcademyPackage.field_id,
            package_name: currentAcademyPackage.name,
            duration_hours: currentAcademyPackage.duration,
            schedule: selected
         })
       });

       if (!isGroup && btn) {
           btn.innerText = 'Programı Onayla ve Öde';
           btn.disabled = false;
       }

       if (ok) {
         document.getElementById('academy-schedule-modal').style.display = 'none';
         ProSaha.toast(data.message || 'Rezervasyonlar başarıyla oluşturuldu!', 'success');
         showPage('my-reservations');
       } else {
         ProSaha.toast(data.error || 'İşlem sırasında bir hata oluştu.', 'error');
       }
    }`;

content = content.replace(oldJS, newJS);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed modal logic');
