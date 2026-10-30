const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const oldComplete = `    async function completeAcademyBooking() {
        if (!window.pendingAcademyBooking) return;
        const btn = document.getElementById('pay-btn');
        btn.innerText = 'İşleniyor...'; btn.disabled = true;

        const { ok, data } = await ProSaha.fetch('/reservations/academy', {
             method: 'POST',
             body: JSON.stringify(window.pendingAcademyBooking)
        });

        if (ok) {
             ProSaha.toast(data.message || 'Ödeme alındı ve takvim oluşturuldu!', 'success');
             showPage('my-reservations');
             window.pendingAcademyBooking = null;
        } else {
             ProSaha.toast(data.error || 'Hata oluştu.', 'error');
             btn.innerText = 'Tekrar Dene'; btn.disabled = false;
        }
    }`;

const newComplete = `    async function completeAcademyBooking() {
        if (!window.pendingAcademyBooking) return;
        const btn = document.getElementById('pay-btn');
        btn.innerText = 'İşleniyor...'; btn.disabled = true;

        // 1. Create the backend reservations (pending status)
        const { ok, data } = await ProSaha.fetch('/reservations/academy', {
             method: 'POST',
             body: JSON.stringify(window.pendingAcademyBooking)
        });

        if (!ok || !data.success) {
             ProSaha.toast(data.error || 'Takvim oluşturulurken hata oluştu.', 'error');
             btn.innerText = 'Tekrar Dene'; btn.disabled = false;
             return;
        }

        // 2. Open payment checkout using the returned group_id
        const resPayment = await ProSaha.fetch('/payment/academy-checkout', {
             method: 'POST',
             body: JSON.stringify({ 
                 group_id: data.group_id,
                 total_amount: window.pendingAcademyBooking.total_amount,
                 package_name: window.pendingAcademyBooking.package_name
             })
        });

        if (resPayment.ok && resPayment.data.success) {
            btn.style.display = 'none';
            document.querySelector('.test-note').style.display = 'none';
            
            let container = document.getElementById('iyzico-container');
            container.innerHTML = '<div id="iyzipay-checkout-form" class="responsive"></div>';
            
            // Extract the script from the response and run it manually
            const temp = document.createElement('div');
            temp.innerHTML = resPayment.data.checkoutFormContent;
            const scripts = temp.getElementsByTagName('script');
            for (let i = 0; i < scripts.length; i++) {
                const s = document.createElement('script');
                s.type = 'text/javascript';
                if (scripts[i].src) s.src = scripts[i].src;
                else s.text = scripts[i].innerHTML;
                document.body.appendChild(s);
            }
        } else {
            ProSaha.toast(resPayment.data?.error || 'Ödeme sistemi yüklenemedi', 'error');
            btn.innerText = 'Tekrar Dene'; btn.disabled = false;
        }
    }`;

content = content.replace(oldComplete, newComplete);
fs.writeFileSync(filePath, content, 'utf8');
console.log('Modified frontend to support Iyzico');
