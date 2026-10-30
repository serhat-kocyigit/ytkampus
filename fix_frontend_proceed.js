const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const oldProceed = `    function proceedToAcademyPayment() {
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
    }`;

const newProceed = `    async function proceedToAcademyPayment() {
       const selected = [];
       for(let i=1; i<=currentAcademyPackage.frequency; i++) {
          selected.push({
             day: document.getElementById('acad-day-'+i).value,
             time: document.getElementById('acad-time-'+i).value
          });
       }
       
       const btn = document.querySelector('#academy-schedule-modal .btn-primary');
       const originalText = btn.innerText;
       btn.innerText = 'Kontrol Ediliyor...';
       btn.disabled = true;

       const { ok, data } = await ProSaha.fetch('/reservations/academy', {
         method: 'POST',
         body: JSON.stringify({
            field_id: currentAcademyPackage.field_id,
            package_name: currentAcademyPackage.name,
            schedule: selected
         })
       });

       btn.innerText = originalText;
       btn.disabled = false;

       if (ok) {
         document.getElementById('academy-schedule-modal').style.display = 'none';
         ProSaha.toast(data.message || 'Rezervasyonlar başarıyla oluşturuldu!', 'success');
         showPage('my-reservations');
       } else {
         ProSaha.toast(data.error || 'İşlem sırasında bir hata oluştu.', 'error');
       }
    }`;

content = content.replace(oldProceed, newProceed);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed proceed function');
