const fs = require('fs');
let c = fs.readFileSync('frontend/pages/user/dashboard.html', 'utf8');

const oldFuncStart = 'async function confirmBooking() {';
const oldFuncEnd = 'loadSlots();\n        }\n      }';

const idxStart = c.indexOf(oldFuncStart);
const idxEnd = c.indexOf(oldFuncEnd, idxStart);

if (idxStart !== -1 && idxEnd !== -1) {
    const newFunc = `async function confirmBooking() {
      const date = document.getElementById('res-date').value;
      const fieldId = document.getElementById('field-select').value;
      if (!date || !selectedSlot) { ProSaha.toast('Tarih ve saat seçin', 'error'); return; }
      
      const btn = document.getElementById('pay-btn');
      btn.disabled = true; btn.innerHTML = '<div class="spinner"></div> İşleniyor...';

      try {
        const token = localStorage.getItem('prosaha_token');
        const res = await fetch('/api/payment/checkout', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': \`Bearer \${token}\`
            },
            body: JSON.stringify({ 
                date, 
                time_slot: selectedSlot, 
                field_id: parseInt(fieldId) 
            })
        });

        const data = await res.json();
        
        if (data.success) {
            // Hide payment panel inputs, show iyzico form
            document.querySelector('.payment-details').style.display = 'none';
            document.getElementById('iyzico-container').innerHTML = data.checkoutFormContent + '<div id="iyzipay-checkout-form" class="responsive"></div>';
        } else {
            ProSaha.toast('İyzico hatası: ' + data.error, 'error');
            btn.disabled = false;
            btn.innerHTML = 'İyzico ile Öde';
        }
      } catch (err) {
        ProSaha.toast('Bağlantı hatası', 'error');
        btn.disabled = false;
        btn.innerHTML = 'İyzico ile Öde';
      }
    }`;

    // Replace the function
    c = c.substring(0, idxStart) + newFunc + c.substring(idxEnd + oldFuncEnd.length);

    // Also add <div id="iyzico-container"></div> below the payment panel if not exists
    if (!c.includes('iyzico-container')) {
       c = c.replace('<div class="payment-details">', '<div id="iyzico-container"></div>\n          <div class="payment-details">');
    }
    
    // Change button text
    c = c.replace('>Ödemeyi Tamamla<', '>İyzico ile Öde<');

    fs.writeFileSync('frontend/pages/user/dashboard.html', c);
    console.log('Iyzico frontend updated');
} else {
    console.log('Could not find function bounds.');
}
