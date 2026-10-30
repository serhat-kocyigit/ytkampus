const fs = require('fs');
const path = require('path');

const filePath = path.join(__dirname, 'frontend', 'pages', 'user', 'dashboard.html');
let content = fs.readFileSync(filePath, 'utf8');

const startMarker = 'function renderMyList(list) {';
const endMarker = '    async function cancelRes(id) {';

const startIdx = content.indexOf(startMarker);
const endIdx = content.indexOf(endMarker);

if (startIdx !== -1 && endIdx !== -1) {
    const newFunc = `function renderMyList(list) {
      const el = document.getElementById('my-res-list');
      if (!list.length) { el.innerHTML = '<div class="empty-state"><div class="icon">📅</div><h3>Rezervasyon bulunamadı</h3></div>'; return; }
      el.innerHTML = \`<table class="data-table"><thead><tr><th>Saha</th><th>Tarih</th><th>Saat</th><th>Tür/Paket</th><th>Süre</th><th>Tutar</th><th>Durum</th><th>Ödeme</th><th>İşlem</th></tr></thead><tbody>
        \${list.map(r => \`<tr>
          <td><strong>\${r.field_name}</strong></td>
          <td>\${ProSaha.formatDate(r.date)}</td>
          <td><span class="badge badge-blue">\${r.time_slot}</span></td>
          <td style="font-size:12px; max-width:150px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;" title="\${r.notes || 'Saatlik'}">\${r.notes ? r.notes.split(' | ')[0] : 'Saatlik'}</td>
          <td>\${r.duration_hours} saat</td>
          <td><strong>\${ProSaha.formatCurrency(r.total_amount)}</strong></td>
          <td>\${statusBadge(r.status)}</td>
          <td><span class="badge \${r.payment_status === 'paid' ? 'badge-green' : r.payment_status === 'refunded' ? 'badge-amber' : 'badge-red'}">\${r.payment_status === 'paid' ? 'Ödendi' : r.payment_status === 'refunded' ? 'İade' : 'Ödenmedi'}</span></td>
          <td>\${r.status === 'confirmed' ? \\\`<button onclick="cancelRes(\${r.id})" class="btn btn-danger btn-sm">İptal Et</button>\\\` : '-'}</td>
        </tr>\`).join('')}
      </tbody></table>\`;
    }

`;
    content = content.substring(0, startIdx) + newFunc + content.substring(endIdx);
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Successfully injected renderMyList with indexOf');
} else {
    console.log('Markers not found');
}
