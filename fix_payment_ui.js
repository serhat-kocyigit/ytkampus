const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

// 1. Fix the setTimeout from 3000 to 1000
content = content.replace(/setTimeout\(\(\) => \{\n             proceedToAcademyPayment\(true\);\n        \}, 3000\);/g, "setTimeout(() => { proceedToAcademyPayment(true); }, 1000);");

// 2. Fix the proceedToAcademyPayment pricing logic
const oldPricing = `       let amount = 8000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 2')) amount = 16000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 3')) amount = 24000;
       if(currentAcademyPackage.name.includes('2 Kişilik')) amount = 12000;
       if(currentAcademyPackage.name.includes('3 Kişilik')) amount = 10000;`;

const newPricing = `       let amount = 8000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 2')) amount = 16000;
       if(currentAcademyPackage.name.includes('Özel') && currentAcademyPackage.name.includes('Haftada 3')) amount = 24000;
       if(currentAcademyPackage.name.includes('2 Kişilik')) amount = 12000;
       if(currentAcademyPackage.name.includes('3 Kişilik')) amount = 10000;
       if(currentAcademyPackage.name.includes('Grup') && currentAcademyPackage.name.includes('Haftada 3')) amount = 12000;`;

content = content.replace(oldPricing, newPricing);


// 3. Fix loadIyzicoForAcademy and completeAcademyBooking to use native elements
const oldIyzico = `    async function loadIyzicoForAcademy(amount) {
        // ... payment logic placeholder, re-using existing if possible
        // I will just mock a success button since Iyzico needs backend generation
        document.getElementById('iyzico-container').innerHTML = \`
           <div style="background:#eef6ff; padding:20px; border-radius:12px; border:1px solid #cce0ff; text-align:center;">
             <h3 style="color:#1e4f86; margin-bottom:10px;">Abonelik Ödeme Ekranı</h3>
             <p style="font-size:14px; color:#333; margin-bottom:20px;">\${ProSaha.formatCurrency(amount)} tutarındaki ödemenizi tamamlayın.</p>
             <button class="btn btn-primary" onclick="completeAcademyBooking()" style="width:100%; padding:15px; font-size:16px;">Ödemeyi Tamamla (Test)</button>
           </div>
        \`;
    }

    async function completeAcademyBooking() {
        if (!window.pendingAcademyBooking) return;
        const btn = document.querySelector('#iyzico-container .btn-primary');
        btn.innerText = 'İşleniyor...'; btn.disabled = true;`;


const newIyzico = `    async function loadIyzicoForAcademy(amount) {
        document.getElementById('iyzico-container').innerHTML = '';
        
        const payBtn = document.getElementById('pay-btn');
        payBtn.innerText = 'İyzico ile Aboneliği Başlat';
        // Overwrite the onclick to call our completeAcademyBooking instead of confirmBooking
        payBtn.onclick = completeAcademyBooking;
    }

    async function completeAcademyBooking() {
        if (!window.pendingAcademyBooking) return;
        const btn = document.getElementById('pay-btn');
        btn.innerText = 'İşleniyor...'; btn.disabled = true;`;

content = content.replace(oldIyzico, newIyzico);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed UI issues and price');
