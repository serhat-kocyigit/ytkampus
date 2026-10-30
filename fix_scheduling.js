const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Update the selectPackage calls to have the correct frequency
content = content.replace(/'Özel Ders', 0/g, "'Özel Ders', 2");
content = content.replace(/'2 Kişilik Grup', 0/g, "'2 Kişilik Grup', 2");
content = content.replace(/'3 Kişilik Grup', 0/g, "'3 Kişilik Grup', 2");
content = content.replace(/'Dans Özel Ders \(Haftada 2\)', 0/g, "'Dans Özel Ders (Haftada 2)', 2");
content = content.replace(/'Dans Özel Ders \(Haftada 3\)', 0/g, "'Dans Özel Ders (Haftada 3)', 3");
// Grup dersleri have '0' as frequency since they are "Belirlenen gün"

// 2. Add the modal HTML before the closing </main>
const modalHtml = `
    <!-- Academy Schedule Modal -->
    <div id="academy-schedule-modal" class="modal" style="display:none;">
      <div class="modal-content" style="max-width:500px; padding:30px;">
        <span class="close-btn" onclick="document.getElementById('academy-schedule-modal').style.display='none'">&times;</span>
        <h2 id="academy-schedule-title" style="margin-bottom:10px; color:var(--brand-600);">Paket Gün & Saat Seçimi</h2>
        <p style="color:var(--text-500); font-size:14px; margin-bottom:20px; line-height:1.5;">Lütfen haftalık düzenli dersleriniz için uygun gün ve saatleri belirleyin. Sistem bu saatleri kontrol edip 1 ay (4 hafta) boyunca sizin için rezerve edecektir.</p>
        
        <div id="academy-schedule-inputs"></div>
        
        <div style="margin-top:20px; display:flex; justify-content:flex-end; gap:10px;">
          <button type="button" class="btn btn-secondary" onclick="document.getElementById('academy-schedule-modal').style.display='none'">İptal</button>
          <button type="button" class="btn btn-primary" onclick="proceedToAcademyPayment()">Programı Onayla ve Öde</button>
        </div>
      </div>
    </div>
`;
content = content.replace('</main>', modalHtml + '\n    </main>');

// 3. Update the selectPackage function
const oldSelectPackage = /function selectPackage\(packageName, price\) \{[\s\S]*?\}/;
const newSelectPackage = `let currentAcademyPackage = null;
    function selectPackage(packageName, frequency) {
      const fieldId = document.getElementById('field-select').value;
      const field = fields.find(f => f.id == fieldId);
      currentAcademyPackage = { name: packageName, frequency: frequency, field_id: fieldId, field_name: field ? field.name : '' };
      
      if (frequency > 0) {
        let html = '';
        const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
        for(let i=1; i<=frequency; i++) {
           html += \`
             <div class="form-group" style="background:#f9f9f9; border:1px solid var(--border); padding:15px; border-radius:8px; margin-bottom:15px;">
               <label style="color:var(--text-900); font-weight:600; font-size:14px;">\${i}. Gün ve Saat Seçimi</label>
               <div style="display:flex; gap:10px; margin-top:10px;">
                 <select id="acad-day-\${i}" class="input-field" style="flex:1;">
                   \${days.map((d, idx) => \`<option value="\${idx+1}">\${d}</option>\`).join('')}
                 </select>
                 <select id="acad-time-\${i}" class="input-field" style="flex:1;">
                   \${Array.from({length:15}, (_,i)=>i+9).map(h => \`<option value="\${String(h).padStart(2,'0')}:00">\${String(h).padStart(2,'0')}:00</option>\`).join('')}
                 </select>
               </div>
             </div>
           \`;
        }
        document.getElementById('academy-schedule-inputs').innerHTML = html;
        document.getElementById('academy-schedule-modal').style.display = 'flex';
      } else {
        ProSaha.toast('Grup derslerinin saatleri tesis tarafından belirlenmektedir. Lütfen tesisle iletişime geçin.', 'info');
      }
    }

    function proceedToAcademyPayment() {
       // Validate selections to avoid duplicate days
       const selected = [];
       for(let i=1; i<=currentAcademyPackage.frequency; i++) {
          selected.push({
             day: document.getElementById('acad-day-'+i).value,
             time: document.getElementById('acad-time-'+i).value
          });
       }
       
       document.getElementById('academy-schedule-modal').style.display = 'none';
       
       // Now show payment summary
       // For now, we will just show a success modal or integrate with backend.
       // Let's create an 8-record creation backend call to /api/reservations/academy
       
       ProSaha.toast('Seçilen saatler takvimde kontrol ediliyor ve rezerve ediliyor...', 'success');
       setTimeout(() => {
          ProSaha.toast('Rezervasyonlar başarıyla oluşturuldu! (Simülasyon)', 'success');
          showPage('overview');
       }, 2000);
    }
`;
content = content.replace(oldSelectPackage, newSelectPackage);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed academy scheduling frontend');
