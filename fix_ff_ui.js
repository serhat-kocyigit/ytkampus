const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Remove the setTimeout delay for group classes
const oldTimeout = `      } else {
        ProSaha.toast('Bu pakette (Grup/Akademi) gün ve saatler tesis tarafından belirlenmektedir. Kaydınız alınıyor, size gün ve saat bilgisi verilecektir.', 'info');
        setTimeout(() => { proceedToAcademyPayment(true); }, 1000);
      }`;

const newTimeout = `      } else {
        proceedToAcademyPayment(true);
      }`;

content = content.replace(oldTimeout, newTimeout);

// 2. Hide no-slot-msg and fix overlapping text
const oldPaymentSetup = `       // Hide the normal res-panel and show payment panel directly
       document.querySelector('.res-panel > div:first-child').style.display = 'none';
       document.getElementById('payment-panel').style.display = 'block';
       document.getElementById('price-display').innerText = ProSaha.formatCurrency(amount);
       document.getElementById('selected-slot-text').innerHTML = \`\${currentAcademyPackage.field_name}<br><span style="font-size:13px;color:var(--brand-500);">\${currentAcademyPackage.name} (\${amount} TL)</span>\`;`;

const newPaymentSetup = `       // Hide the normal res-panel and show payment panel directly
       document.querySelector('.res-panel > div:first-child').style.display = 'none';
       document.getElementById('payment-panel').style.display = 'block';
       const noSlotMsg = document.getElementById('no-slot-msg');
       if(noSlotMsg) noSlotMsg.style.display = 'none'; // Hide pointing hand
       document.getElementById('price-display').innerText = ProSaha.formatCurrency(amount);
       document.getElementById('selected-slot-text').innerHTML = \`
           <div style="max-width: 160px; line-height: 1.4; word-wrap: break-word; overflow-wrap: break-word;">
               <div style="color:var(--text-900);">\${currentAcademyPackage.field_name}</div>
               <div style="font-size:12px; font-weight:500; color:var(--brand-500); margin-top:2px;">\${currentAcademyPackage.name}</div>
           </div>
       \`;`;

content = content.replace(oldPaymentSetup, newPaymentSetup);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed fast forward and UI overlap');
