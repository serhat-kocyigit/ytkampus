const fs = require('fs');
let c = fs.readFileSync('frontend/mac-izle.html', 'utf8');

const htmlStart = '<div id="clip-controls"';
const htmlEnd = 'Kliplerim</h4>';

const newHtml = `<div id="clip-controls" style="display:none; background: var(--bg-900); padding:16px; border-radius:8px; border:1px solid var(--border); width: 100%; box-sizing: border-box; overflow: hidden;">
          
          <div style="font-size:13px; color:var(--text-300); margin-bottom:12px; text-align:center;">Kesilecek Zaman Aralığını Girin (Dakika:Saniye)</div>
          
          <div style="display: flex; gap: 12px; margin-bottom: 12px;">
              <div style="flex: 1; background: var(--bg-800); padding: 12px; border-radius: 6px; border: 1px solid var(--border);">
                  <div style="font-size:11px; color:var(--text-300); margin-bottom:4px; text-align:center;">BAŞLANGIÇ</div>
                  <div style="display:flex; justify-content:center; align-items:center; gap:2px; font-weight:bold;">
                      <input type="number" id="start-min" min="0" max="60" value="00" style="width:40px; text-align:center; background:rgba(0,0,0,0.2); border:1px solid var(--border); color:white; font-size:20px; font-weight:bold; padding:4px; border-radius:4px;" onchange="padTime(this)" oninput="updateEndFromDuration()">
                      <span style="font-size:20px;">:</span>
                      <input type="number" id="start-sec" min="0" max="59" value="00" style="width:40px; text-align:center; background:rgba(0,0,0,0.2); border:1px solid var(--border); color:white; font-size:20px; font-weight:bold; padding:4px; border-radius:4px;" onchange="padTime(this)" oninput="updateEndFromDuration()">
                  </div>
              </div>
              <div style="display:flex; align-items:center; color:var(--text-500); font-weight:bold;">-</div>
              <div style="flex: 1; background: var(--bg-800); padding: 12px; border-radius: 6px; border: 1px solid var(--border);">
                  <div style="font-size:11px; color:var(--text-300); margin-bottom:4px; text-align:center;">BİTİŞ</div>
                  <div style="display:flex; justify-content:center; align-items:center; gap:2px; font-weight:bold;">
                      <input type="number" id="end-min" min="0" max="60" value="01" style="width:40px; text-align:center; background:rgba(0,0,0,0.2); border:1px solid var(--border); color:white; font-size:20px; font-weight:bold; padding:4px; border-radius:4px;" onchange="padTime(this)">
                      <span style="font-size:20px;">:</span>
                      <input type="number" id="end-sec" min="0" max="59" value="00" style="width:40px; text-align:center; background:rgba(0,0,0,0.2); border:1px solid var(--border); color:white; font-size:20px; font-weight:bold; padding:4px; border-radius:4px;" onchange="padTime(this)">
                  </div>
              </div>
          </div>
          
          <div style="font-size:11px; color:var(--text-300); margin-bottom:6px; text-align:center;">Veya otomatik süre ekle:</div>
          <div style="display:grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap:6px; margin-bottom:16px;">
              <button class="btn btn-secondary" onclick="addDuration(15)" style="padding:6px; font-size:12px;">+15 Sn</button>
              <button class="btn btn-secondary" onclick="addDuration(30)" style="padding:6px; font-size:12px;">+30 Sn</button>
              <button class="btn btn-secondary" onclick="addDuration(60)" style="padding:6px; font-size:12px;">+1 Dk</button>
              <button class="btn btn-secondary" onclick="addDuration(120)" style="padding:6px; font-size:12px;">+2 Dk</button>
          </div>
          
          <button class="btn btn-secondary" onclick="previewClip()" style="width:100%; margin-bottom:12px; font-weight:bold;">▶️ Sahneyi Videoda Önizle</button>
          <button class="btn btn-primary" style="width:100%; background:#2563eb; color:#fff;" onclick="saveCustomClip()">✂️ Kesiti Listeye Ekle</button>
        </div>
        
        <h4 style="margin: 10px 0 0 0; font-size:14px; border-bottom:1px solid var(--border); padding-bottom:8px;">Kliplerim</h4>`;

const htmlStartIdx = c.indexOf(htmlStart);
const htmlEndIdx = c.indexOf(htmlEnd);
if (htmlStartIdx !== -1 && htmlEndIdx !== -1) {
    c = c.substring(0, htmlStartIdx) + newHtml + c.substring(htmlEndIdx + htmlEnd.length);
}

const jsStart = 'let clipStart = 0;';
const jsEnd = 'async function downloadClip(btn, start, end) {';

const jsStartIdx = c.indexOf(jsStart);
const jsEndIdx = c.indexOf(jsEnd);

const newJs = `
    let currentDurationSec = 60; // default 1 min range

    function initSlider() {
        // Nothing to init for the new UI since it's just inputs!
    }

    function padTime(input) {
        if (input.value === '') input.value = '00';
        else if (parseInt(input.value) < 10 && input.value.length === 1) input.value = '0' + input.value;
    }

    function getTimeInSeconds(type) {
        const m = parseInt(document.getElementById(type + '-min').value || 0, 10);
        const s = parseInt(document.getElementById(type + '-sec').value || 0, 10);
        return (m * 60) + s;
    }

    function updateEndFromDuration() {
        const startSec = getTimeInSeconds('start');
        const endSec = startSec + currentDurationSec;
        
        const m = Math.floor(endSec / 60);
        const s = endSec % 60;
        
        document.getElementById('end-min').value = String(m).padStart(2, '0');
        document.getElementById('end-sec').value = String(s).padStart(2, '0');
    }

    function addDuration(seconds) {
        currentDurationSec = seconds;
        updateEndFromDuration();
    }

    function previewClip() {
        const startSec = getTimeInSeconds('start');
        const video = document.getElementById('match-video');
        video.currentTime = startSec;
        video.play().catch(() => console.log("Play engellendi"));
    }
    
    function saveCustomClip() {
      const clipStart = getTimeInSeconds('start');
      const clipEnd = getTimeInSeconds('end');
      
      if (clipStart >= clipEnd) {
          alert('Bitiş süresi, başlangıç süresinden büyük olmalıdır!');
          return;
      }

      const list = document.getElementById('clip-list');
      if (clipCounter === 1) {
        list.innerHTML = '';
      }

      const clipHTML = \`
        <div class="clip-item">
          <div>
            <div class="clip-item-title">Kesit #\${clipCounter}</div>
            <div class="clip-item-info" style="word-break: break-all;">Süre: \${formatTime(clipStart)} - \${formatTime(clipEnd)}</div>
          </div>
          <button class="btn-download" style="flex-shrink:0; background:#2563eb; color:#fff; border:none; padding:6px 12px; border-radius:4px; font-weight:bold; cursor:pointer;" onclick="downloadClip(this, \${clipStart}, \${clipEnd})">İndir</button>
        </div>
      \`;

      list.innerHTML = clipHTML + list.innerHTML;
      clipCounter++;
      toggleClipMode();
    }
    
    async function downloadClip(btn, start, end) {`;

if (jsStartIdx !== -1 && jsEndIdx !== -1) {
    c = c.substring(0, jsStartIdx) + newJs + c.substring(jsEndIdx + jsEnd.length - 'async function downloadClip(btn, start, end) {'.length);
}

fs.writeFileSync('frontend/mac-izle.html', c);
console.log('UI Overhauled');
