/**
 * Tasarım Editörü — editor.js
 * Drag, Resize, Properties Panel
 * Varsayılan konumlar scoreboard.css sb-* sınıflarıyla BİREBİR eşleşir.
 */

let currentLayout = null;
let selectedElement = null;
let layoutConfig = {};
let isDragging = false;
let isResizing = false;
let resizeDir = null;
let history = [];
let historyIndex = -1;
let isApplyingHistory = false;

const THEMES = {
  midnight: { background: '#02030e', accent: '#00ff88', panel: '#0f172a', text: '#ffffff', border: '#1e293b' },
  pitch: { background: '#062d1a', accent: '#d8ff49', panel: '#0e4a2b', text: '#ffffff', border: '#55a66f' },
  arena: { background: '#180724', accent: '#ff4fd8', panel: '#301044', text: '#fff7fe', border: '#8e47a8' },
  clean: { background: '#e9eef5', accent: '#1267d6', panel: '#ffffff', text: '#13233b', border: '#b7c7dd' }
};

// Drag state
let dragStartX, dragStartY, elemStartX, elemStartY;
// Resize state
let rsStartX, rsStartY, rsStartW, rsStartH, rsElemX, rsElemY;
let activeInner = null, innerMode = null, innerDir = null, innerStart = null;

const TEAM_INNER_DEFAULTS = {
  logo:  { x: 25, y: 5,  w: 50, h: 38, scale: 1 },
  name:  { x: 4,  y: 47, w: 92, h: 19, scale: 1 },
  yellow:{ x: 12, y: 74, w: 34, h: 17, scale: 1 },
  red:   { x: 54, y: 74, w: 34, h: 17, scale: 1 }
};
const SCORE_INNER_DEFAULTS = {
  homeScore: { x: 5,  y: 10, w: 30, h: 80, scale: 1 },
  separator: { x: 40, y: 10, w: 20, h: 80, scale: 1 },
  awayScore: { x: 65, y: 10, w: 30, h: 80, scale: 1 }
};
const GENERIC_INNER_DEFAULTS = {
  fieldLogo: { logo:{x:4,y:10,w:30,h:80,scale:1}, name:{x:38,y:10,w:58,h:80,scale:1} },
  period: { status:{x:0,y:0,w:100,h:55,scale:1}, clock:{x:0,y:55,w:100,h:45,scale:1} },
  timer: { time:{x:0,y:0,w:100,h:100,scale:1} },
  lastGoal: { icon:{x:3,y:12,w:10,h:76,scale:1}, text:{x:16,y:0,w:80,h:100,scale:1} },
  adBanner: { image:{x:0,y:0,w:100,h:100,scale:1} }
};
const GENERIC_INNER_SELECTORS = {
  fieldLogo: { logo:'.field-logo', name:'.field-name' }, period:{ status:'.period-content', clock:'.real-time-clock' },
  timer:{ time:'.timer-display' }, lastGoal:{ icon:'.last-goal-icon', text:'.last-goal-text' }, adBanner:{ image:'.ad-image' }
};

// ============================================================
// VARSAYILAN DÜZEN
// !! Bu değerler scoreboard.css'deki sb-* sınıf değerleriyle
//    BİREBİR AYNI olmalı (yüzde cinsinden).
// ============================================================
const DEFAULT_LAYOUT = {
  fieldLogoLeft:  { x: 1,  y: 2,  w: 10, h: 12, visible: true },
  fieldLogoRight: { x: 89, y: 2,  w: 10, h: 12, visible: true },
  fieldLogo: { x: 1,  y: 2,  w: 18, h: 12, visible: true },
  period:    { x: 36, y: 2,  w: 26, h: 8,  visible: true },
  timer:     { x: 73, y: 2,  w: 25, h: 12, visible: true },
  teamHome:  { x: 2,  y: 16, w: 27, h: 58, visible: true },
  score:     { x: 31, y: 22, w: 36, h: 44, visible: true },
  teamAway:  { x: 70, y: 16, w: 27, h: 58, visible: true },
  lastGoal:  { x: 18, y: 77, w: 62, h: 9,  visible: true  },
  adBanner:  { x: 0,  y: 92, w: 100,h: 8,  visible: true },
  theme: { ...THEMES.midnight }
};

// ============================================================
// BAŞLATMA
// ============================================================
document.addEventListener('DOMContentLoaded', () => {
  SocketClient.connect();
  initDraggables();
  initComponentPanel();
  initStudioControls();
  loadLayouts();
  loadActiveLayout();
});

// ============================================================
// LAYOUT YÖNETİMİ
// ============================================================
async function loadLayouts() {
  const res = await API.get('/layouts');
  const sel = document.getElementById('layoutSelect');
  sel.innerHTML = '<option value="">— Layout Seçin —</option>';
  if (res.success) {
    res.data.forEach(l => {
      const o = document.createElement('option');
      o.value = l.id;
      o.textContent = l.name + (l.is_active ? ' ✓' : '');
      sel.appendChild(o);
    });
  }
}

async function loadActiveLayout() {
  const res = await API.get('/layouts/active');
  if (res.success && res.data) {
    currentLayout = res.data;
    layoutConfig = normaliseConfig(parseConfig(res.data.config));
    document.getElementById('layoutSelect').value = res.data.id;
  } else {
    layoutConfig = deepClone(DEFAULT_LAYOUT);
  }
  applyToPreview();
  recordHistory(true);
}

function parseConfig(c) {
  return typeof c === 'string' ? JSON.parse(c) : (c || deepClone(DEFAULT_LAYOUT));
}

function deepClone(obj) { return JSON.parse(JSON.stringify(obj)); }

/** Config'i önizlemeye uygula */
function applyToPreview() {
  const theme = layoutConfig.theme || THEMES.midnight;
  document.getElementById('previewContainer').style.background = theme.background;
  document.documentElement.style.setProperty('--primary', theme.accent || '#00ff88');
  document.querySelector('.preview-bg-grid').style.display = document.getElementById('showGrid')?.checked === false ? 'none' : '';
  Object.entries(layoutConfig).forEach(([key, cfg]) => {
    const el = document.getElementById(`drag-${key}`);
    if (!el) return;
    if (cfg.x !== undefined) el.style.left   = cfg.x + '%';
    if (cfg.y !== undefined) el.style.top    = cfg.y + '%';
    if (cfg.w !== undefined) el.style.width  = (key === 'adBanner' ? 100 : cfg.w) + '%';
    if (cfg.h !== undefined) el.style.height = cfg.h + '%';
    el.style.display = cfg.visible === false ? 'none' : '';
    el.style.opacity = '1';
    document.querySelector(`.component-item[data-component="${key}"]`)?.classList.toggle('is-removed', cfg.visible === false);
    el.style.zIndex = cfg.z || 2;
    applyElementAppearance(el, cfg.style, theme);
  });
  updateThemeInputs();
}

/** Ekrandaki pozisyonları config'e kaydet */
function syncConfigFromDOM() {
  const c = document.getElementById('previewContainer');
  document.querySelectorAll('.draggable').forEach(el => {
    const key = el.dataset.key; if (!key) return;
    if (!layoutConfig[key]) layoutConfig[key] = {};
    layoutConfig[key].x = round1(el.offsetLeft / c.offsetWidth  * 100);
    layoutConfig[key].y = round1(el.offsetTop  / c.offsetHeight * 100);
    layoutConfig[key].w = key === 'adBanner' ? 100 : round1(el.offsetWidth  / c.offsetWidth  * 100);
    layoutConfig[key].h = round1(el.offsetHeight / c.offsetHeight * 100);
    layoutConfig[key].z = Number(el.style.zIndex || 2);
  });
}

function round1(v) { return Math.round(v * 10) / 10; }

async function saveLayout() {
  syncConfigFromDOM();
  if (currentLayout) {
    const res = await API.put(`/layouts/${currentLayout.id}`, { config: layoutConfig });
    if (res.success) showToast('✅ Layout kaydedildi!', 'success');
  } else {
    const name = prompt('Layout adı:', 'Yeni Layout');
    if (!name) return;
    const res = await API.post('/layouts', { name, config: layoutConfig });
    if (res.success) { currentLayout = res.data; await loadLayouts(); document.getElementById('layoutSelect').value = currentLayout.id; showToast('✅ Oluşturuldu!', 'success'); }
  }
}

async function activateLayout() {
  if (!currentLayout) return showToast('⚠️ Önce kaydedin', 'warning');
  await API.put(`/layouts/${currentLayout.id}/activate`);
  loadLayouts();
  showToast('🚀 TV\'de güncellendi!', 'success');
}

function resetLayout() {
  layoutConfig = deepClone(DEFAULT_LAYOUT);
  applyToPreview();
  deselectAll();
  recordHistory();
}

function newLayout() {
  currentLayout = null;
  document.getElementById('layoutSelect').value = '';
  resetLayout();
}

document.getElementById('layoutSelect').addEventListener('change', async (e) => {
  if (!e.target.value) return;
  const res = await API.get('/layouts');
  if (res.success) {
    const l = res.data.find(x => x.id === parseInt(e.target.value));
    if (l) { currentLayout = l; layoutConfig = normaliseConfig(parseConfig(l.config)); applyToPreview(); recordHistory(true); }
  }
});

// ============================================================
// DRAG & DROP + RESIZE
// ============================================================
function initDraggables() {
  document.querySelectorAll('.draggable').forEach(el => {
    addResizeHandles(el);
    if (['teamHome', 'teamAway'].includes(el.dataset.key)) initTeamInnerDraggables(el);
    if (el.dataset.key === 'score') initScoreInnerDraggables(el);
    if (GENERIC_INNER_SELECTORS[el.dataset.key]) initGenericInnerDraggables(el);

    el.addEventListener('mousedown', (e) => {
      if (e.target.classList.contains('resize-handle')) return;
      e.preventDefault();
      selectElement(el);
      startDrag(e.clientX, e.clientY, el);
    });

    el.addEventListener('touchstart', (e) => {
      if (e.target.classList.contains('resize-handle')) return;
      e.preventDefault();
      selectElement(el);
      const t = e.touches[0];
      startDrag(t.clientX, t.clientY, el);
    }, { passive: false });
  });

  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp);
  // İç parçaları dış kartın olaylarından önce yakala; rozetler ve metinler
  // artık her tarayıcıda doğrudan sürüklenebilir.
  document.getElementById('previewContainer').addEventListener('pointerdown', (event) => {
    if (event.target.closest('.inner-resize-handle')) return;
    const node = event.target.closest('[data-inner-part]');
    if (!node) return;
    const container = node.closest('.draggable');
    if (!container) return;
    event.preventDefault(); event.stopImmediatePropagation();
    startInnerDrag(event, container, node, node.dataset.innerPart);
  }, true);
  document.addEventListener('pointermove', onMove);
  document.addEventListener('pointerup', onUp);
  document.addEventListener('touchmove', (e) => { e.preventDefault(); onMove(e.touches[0]); }, { passive: false });
  document.addEventListener('touchend', onUp);

  document.getElementById('previewContainer').addEventListener('click', (e) => {
    if (e.target === e.currentTarget) deselectAll();
  });
}

function addResizeHandles(el) {
  ['se','sw','ne','nw','e','w','s','n'].forEach(dir => {
    const h = document.createElement('div');
    h.className = `resize-handle resize-${dir}`;
    h.dataset.dir = dir;
    h.addEventListener('mousedown', (e) => { e.stopPropagation(); e.preventDefault(); startResize(e.clientX, e.clientY, el, dir); });
    h.addEventListener('touchstart', (e) => { e.stopPropagation(); e.preventDefault(); startResize(e.touches[0].clientX, e.touches[0].clientY, el, dir); }, { passive: false });
    el.appendChild(h);
  });
}

function ensureTeamInnerConfig(teamEl) {
  const key = teamEl.dataset.key; const style = layoutConfig[key].style ||= {}; const inner = style.inner ||= {};
  ['logo', 'name', 'yellow', 'red'].forEach(part => { inner[part] = { ...TEAM_INNER_DEFAULTS[part], ...(inner[part] || {}) }; });
  teamEl.classList.add('team-custom-layout');
  applyTeamInnerAppearance(teamEl, inner);
  return inner;
}

function ensureScoreInnerConfig(scoreEl) {
  const key = scoreEl.dataset.key; const style = layoutConfig[key].style ||= {}; const inner = style.inner ||= {};
  Object.keys(SCORE_INNER_DEFAULTS).forEach(part => { inner[part] = { ...SCORE_INNER_DEFAULTS[part], ...(inner[part] || {}) }; });
  scoreEl.classList.add('score-custom-layout'); applyScoreInnerAppearance(scoreEl, inner); return inner;
}

function ensureGenericInnerConfig(containerEl) {
  const key = containerEl.dataset.key; const defaults = GENERIC_INNER_DEFAULTS[key] || {};
  const style = layoutConfig[key].style ||= {}; const inner = style.inner ||= {};
  Object.keys(defaults).forEach(part => { inner[part] = { ...defaults[part], ...(inner[part] || {}) }; });
  applyGenericInnerAppearance(containerEl, inner); return inner;
}

function initTeamInnerDraggables(teamEl) {
  [['logo', '.team-logo-wrapper'], ['name', '.team-name'], ['yellow', '.yellow-badge'], ['red', '.red-badge']].forEach(([part, selector]) => {
    const node = teamEl.querySelector(selector); if (!node) return;
    node.dataset.innerPart = part;
    addInnerResizeHandles(node, part);
    node.addEventListener('mousedown', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event, teamEl, node, part); });
    node.addEventListener('touchstart', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event.touches[0], teamEl, node, part); }, { passive:false });
  });
}

function initScoreInnerDraggables(scoreEl) {
  [['homeScore', '.score-home'], ['separator', '.score-separator'], ['awayScore', '.score-away']].forEach(([part, selector]) => {
    const node = scoreEl.querySelector(selector); if (!node) return;
    node.dataset.innerPart = part;
    addInnerResizeHandles(node, part);
    node.addEventListener('mousedown', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event, scoreEl, node, part); });
    node.addEventListener('touchstart', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event.touches[0], scoreEl, node, part); }, { passive:false });
  });
}

function initGenericInnerDraggables(containerEl) {
  Object.entries(GENERIC_INNER_SELECTORS[containerEl.dataset.key]).forEach(([part, selector]) => {
    const node = containerEl.querySelector(selector); if (!node) return;
    node.dataset.innerPart = part;
    addInnerResizeHandles(node, part);
    node.addEventListener('mousedown', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event, containerEl, node, part); });
    node.addEventListener('touchstart', event => { if (event.target.classList.contains('inner-resize-handle')) return; event.preventDefault(); event.stopPropagation(); startInnerDrag(event.touches[0], containerEl, node, part); }, { passive:false });
  });
}

function addInnerResizeHandles(node, part) {
  ['se','sw','ne','nw','e','w','s','n'].forEach(dir => { const handle = document.createElement('div'); handle.className = `inner-resize-handle inner-resize-${dir}`; handle.addEventListener('mousedown', event => { event.preventDefault(); event.stopPropagation(); startInnerResize(event, node.closest('.draggable'), node, part, dir); }); handle.addEventListener('touchstart', event => { event.preventDefault(); event.stopPropagation(); startInnerResize(event.touches[0], node.closest('.draggable'), node, part, dir); }, { passive:false }); node.appendChild(handle); });
}

function startInnerDrag(event, teamEl, node, part) {
  selectElement(teamEl); if (teamEl.dataset.key === 'score') ensureScoreInnerConfig(teamEl); else if (['teamHome','teamAway'].includes(teamEl.dataset.key)) ensureTeamInnerConfig(teamEl); else ensureGenericInnerConfig(teamEl); document.querySelectorAll('.inner-selected').forEach(el => el.classList.remove('inner-selected')); node.classList.add('inner-selected');
  activeInner = { teamEl, node, part }; innerMode = 'drag'; innerStart = { cx:event.clientX, cy:event.clientY, x:node.offsetLeft, y:node.offsetTop, w:node.offsetWidth, h:node.offsetHeight };
  if (teamEl.dataset.key !== 'score') { document.getElementById('innerPart').value = part; populateTeamInnerControls(); }
}

function startInnerResize(event, teamEl, node, part, dir) {
  startInnerDrag(event, teamEl, node, part); innerMode = 'resize'; innerDir = dir;
}

function doInnerMove(event) {
  if (!activeInner || !innerStart) return;
  const { teamEl, node, part } = activeInner; const dx = event.clientX - innerStart.cx, dy = event.clientY - innerStart.cy; let x = innerStart.x, y = innerStart.y, w = innerStart.w, h = innerStart.h;
  if (innerMode === 'drag') { x += dx; y += dy; }
  else { if (innerDir.includes('e')) w += dx; if (innerDir.includes('s')) h += dy; if (innerDir.includes('w')) { w -= dx; x += dx; } if (innerDir.includes('n')) { h -= dy; y += dy; } }
  w = Math.max(24, w); h = Math.max(20, h); x = clamp(x, 0, teamEl.offsetWidth - w); y = clamp(y, 0, teamEl.offsetHeight - h); w = Math.min(w, teamEl.offsetWidth - x); h = Math.min(h, teamEl.offsetHeight - y);
  const inner = teamEl.dataset.key === 'score' ? ensureScoreInnerConfig(teamEl) : ['teamHome','teamAway'].includes(teamEl.dataset.key) ? ensureTeamInnerConfig(teamEl) : ensureGenericInnerConfig(teamEl); Object.assign(inner[part], { x:round1(x / teamEl.offsetWidth * 100), y:round1(y / teamEl.offsetHeight * 100), w:round1(w / teamEl.offsetWidth * 100), h:round1(h / teamEl.offsetHeight * 100) });
  if (teamEl.dataset.key === 'score') applyScoreInnerAppearance(teamEl, inner); else if (['teamHome','teamAway'].includes(teamEl.dataset.key)) { applyTeamInnerAppearance(teamEl, inner); populateTeamInnerControls(); } else applyGenericInnerAppearance(teamEl, inner); markDirty();
}

function startDrag(cx, cy, el) {
  isDragging = true; selectedElement = el;
  el.classList.add('dragging');
  dragStartX = cx; dragStartY = cy;
  elemStartX = el.offsetLeft; elemStartY = el.offsetTop;
}

function startResize(cx, cy, el, dir) {
  isResizing = true; resizeDir = dir; selectedElement = el;
  rsStartX = cx; rsStartY = cy;
  rsStartW = el.offsetWidth;  rsStartH = el.offsetHeight;
  rsElemX  = el.offsetLeft;   rsElemY  = el.offsetTop;
}

function onMove(e) {
  if (activeInner) { doInnerMove(e); return; }
  if (isDragging && selectedElement)  doDrag(e.clientX, e.clientY);
  if (isResizing && selectedElement)  doResize(e.clientX, e.clientY);
}

function doDrag(cx, cy) {
  const c = document.getElementById('previewContainer');
  let nx = elemStartX + (cx - dragStartX);
  let ny = elemStartY + (cy - dragStartY);
  nx = clamp(nx, 0, c.offsetWidth  - selectedElement.offsetWidth);
  ny = clamp(ny, 0, c.offsetHeight - selectedElement.offsetHeight);
  if (document.getElementById('snapToGrid')?.checked) { nx = snap(nx, c.offsetWidth); ny = snap(ny, c.offsetHeight); }
  selectedElement.style.left = nx + 'px';
  selectedElement.style.top  = ny + 'px';
  updatePropsPanel(selectedElement);
}

function doResize(cx, cy) {
  const c = document.getElementById('previewContainer');
  const dx = cx - rsStartX, dy = cy - rsStartY;
  const key = selectedElement.dataset.key;
  const minW = 30, minH = 16;
  let nw = rsStartW, nh = rsStartH, nx = rsElemX, ny = rsElemY;

  if (resizeDir.includes('e')) nw = Math.max(minW, rsStartW + dx);
  if (resizeDir.includes('s')) nh = Math.max(minH, rsStartH + dy);
  if (resizeDir.includes('w')) { nw = Math.max(minW, rsStartW - dx); nx = rsElemX + (rsStartW - nw); }
  if (resizeDir.includes('n')) { nh = Math.max(minH, rsStartH - dy); ny = rsElemY + (rsStartH - nh); }

  if (key === 'adBanner') { nw = c.offsetWidth; nx = 0; }

  nx = clamp(nx, 0, Infinity); ny = clamp(ny, 0, Infinity);
  if (nx + nw > c.offsetWidth)  nw = c.offsetWidth  - nx;
  if (ny + nh > c.offsetHeight) nh = c.offsetHeight - ny;

  selectedElement.style.left   = nx + 'px';
  selectedElement.style.top    = ny + 'px';
  selectedElement.style.width  = nw + 'px';
  selectedElement.style.height = nh + 'px';
  updatePropsPanel(selectedElement);
}

function onUp() {
  if (activeInner) { activeInner = null; innerMode = null; innerDir = null; innerStart = null; recordHistory(); return; }
  if (selectedElement) selectedElement.classList.remove('dragging');
  isDragging = false; isResizing = false; resizeDir = null;
  if (selectedElement) { syncConfigFromDOM(); recordHistory(); markDirty(); }
}

function clamp(v, min, max) { return Math.max(min, Math.min(max, v)); }

// ============================================================
// SEÇİM & ÖZELLIKLER
// ============================================================
function initComponentPanel() {
  document.querySelectorAll('.component-item').forEach(item => {
    item.addEventListener('click', () => {
      const el = document.getElementById(`drag-${item.dataset.component}`);
      if (el) { restoreComponent(item.dataset.component); selectElement(el); }
    });
  });
}

function removeSelectedComponent() {
  if (!selectedElement) return;
  const key = selectedElement.dataset.key; layoutConfig[key].visible = false;
  selectedElement.style.display = 'none';
  document.querySelector(`.component-item[data-component="${key}"]`)?.classList.add('is-removed');
  deselectAll(); markDirty(); recordHistory(); showToast('Bileşen tasarımdan kaldırıldı', 'info');
}

function restoreComponent(key) {
  if (!layoutConfig[key]) layoutConfig[key] = {};
  layoutConfig[key].visible = true;
  const el = document.getElementById(`drag-${key}`); if (el) el.style.display = '';
  document.querySelector(`.component-item[data-component="${key}"]`)?.classList.remove('is-removed');
  markDirty(); recordHistory();
}

function selectElement(el) {
  deselectAll();
  el.classList.add('selected');
  selectedElement = el;
  document.querySelectorAll('.component-item').forEach(ci => {
    ci.classList.toggle('active', ci.dataset.component === el.dataset.key);
  });
  updatePropsPanel(el);
  document.getElementById('propertiesPanel').style.display = 'block';

  // Başlık
  const labels = { fieldLogo:'Saha Bilgisi', fieldLogoLeft:'Sol Logo', fieldLogoRight:'Sağ Logo', period:'Devre', timer:'Sayaç',
    teamHome:'Ev Sahibi', score:'Skor', teamAway:'Deplasman',
    lastGoal:'Son Gol', adBanner:'Reklam Bandı' };
  document.getElementById('selectedLabel').textContent = labels[el.dataset.key] || 'Özellikler';
}

function deselectAll() {
  document.querySelectorAll('.draggable').forEach(el => el.classList.remove('selected'));
  document.querySelectorAll('.component-item').forEach(ci => ci.classList.remove('active'));
  document.getElementById('propertiesPanel').style.display = 'none';
  selectedElement = null;
}

function updatePropsPanel(el) {
  const c = document.getElementById('previewContainer');
  document.getElementById('propX').value = round1(el.offsetLeft / c.offsetWidth  * 100);
  document.getElementById('propY').value = round1(el.offsetTop  / c.offsetHeight * 100);
  document.getElementById('propW').value = round1(el.offsetWidth  / c.offsetWidth  * 100);
  document.getElementById('propH').value = round1(el.offsetHeight / c.offsetHeight * 100);
  const key = el.dataset.key;
  const style = (layoutConfig[key] && layoutConfig[key].style) || {};
  document.getElementById('propBackground').value = style.background || rgbToHex(getComputedStyle(el).backgroundColor, '#0f172a');
  document.getElementById('propColor').value = style.color || rgbToHex(getComputedStyle(el).color, '#ffffff');
  document.getElementById('propAccent').value = style.accent || style.color || '#ffffff';
  document.getElementById('propBorder').value = style.borderColor || rgbToHex(getComputedStyle(el).borderColor, '#1e293b');
  document.getElementById('propRadius').value = style.radius ?? (parseInt(getComputedStyle(el).borderRadius) || 10);
  document.getElementById('propRadiusOut').textContent = document.getElementById('propRadius').value;
  document.getElementById('propOpacity').value = Math.round((style.opacity ?? 1) * 100);
  document.getElementById('propOpacityOut').textContent = document.getElementById('propOpacity').value;
  document.getElementById('propFontScale').value = Math.round((style.fontScale ?? 1) * 100);
  document.getElementById('propFontScaleOut').textContent = document.getElementById('propFontScale').value;
  document.getElementById('propFontFamily').value = style.fontFamily || 'inherit';
  document.getElementById('propFontWeight').value = style.fontWeight || 'inherit';
  document.getElementById('propLetterSpacing').value = style.letterSpacing ?? 0;
  document.getElementById('propLetterSpacingOut').textContent = style.letterSpacing ?? 0;
  document.getElementById('propLineHeight').value = Math.round((style.lineHeight ?? 1.2) * 100);
  document.getElementById('propLineHeightOut').textContent = document.getElementById('propLineHeight').value;
  document.getElementById('propTextAlign').value = style.textAlign || 'center';
  document.getElementById('propTextShadow').checked = style.textShadow !== false;
  const isTeamPanel = ['teamHome', 'teamAway'].includes(key);
  document.getElementById('logoControls').style.display = isTeamPanel ? 'block' : 'none';
  document.getElementById('teamInnerControls').style.display = isTeamPanel ? 'block' : 'none';
  if (isTeamPanel) {
    document.getElementById('propLogoScale').value = Math.round((style.logoScale ?? 1) * 100);
    document.getElementById('propLogoScaleOut').textContent = document.getElementById('propLogoScale').value;
    document.getElementById('propLogoFit').value = style.logoFit || 'contain';
    populateTeamInnerControls();
  }
}

function updateProperty(prop) {
  if (!selectedElement) return;
  const key = selectedElement.dataset.key;
  const c = document.getElementById('previewContainer');
  if (!layoutConfig[key]) layoutConfig[key] = {};

  if (prop === 'x') {
    const v = parseFloat(document.getElementById('propX').value) || 0;
    selectedElement.style.left = v + '%'; layoutConfig[key].x = v;
  } else if (prop === 'y') {
    const v = parseFloat(document.getElementById('propY').value) || 0;
    selectedElement.style.top  = v + '%'; layoutConfig[key].y = v;
  } else if (prop === 'w') {
    const v = parseFloat(document.getElementById('propW').value) || 10;
    selectedElement.style.width = (key === 'adBanner' ? 100 : v) + '%'; layoutConfig[key].w = v;
  } else if (prop === 'h') {
    const v = parseFloat(document.getElementById('propH').value) || 5;
    selectedElement.style.height = v + '%'; layoutConfig[key].h = v;
  }
  markDirty(); recordHistory();
}

function initStudioControls() {
  document.getElementById('undoBtn').addEventListener('click', undo);
  document.getElementById('redoBtn').addEventListener('click', redo);
  document.getElementById('themeBackground').addEventListener('input', () => updateTheme('background'));
  ['background', 'panel', 'text', 'accent', 'border'].forEach(property => {
    document.getElementById(`theme${property[0].toUpperCase()}${property.slice(1)}`).addEventListener('input', () => updateTheme(property));
  });
  document.getElementById('showGrid').addEventListener('change', applyToPreview);
  document.querySelectorAll('#themePresets button').forEach(btn => btn.addEventListener('click', () => applyTheme(btn.dataset.theme)));
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); e.shiftKey ? redo() : undo(); }
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'y') { e.preventDefault(); redo(); }
    if (!selectedElement || ['INPUT', 'SELECT', 'TEXTAREA'].includes(document.activeElement.tagName)) return;
    const move = e.shiftKey ? 2 : .5;
    if (['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)) {
      e.preventDefault(); nudgeSelected(e.key, move);
    }
  });
}

function normaliseConfig(config) {
  const next = deepClone(DEFAULT_LAYOUT);
  Object.entries(config || {}).forEach(([key, value]) => {
    if (key === 'theme') return;
    const migrated = { ...value };
    if (migrated.width !== undefined && migrated.w === undefined) migrated.w = migrated.width;
    if (migrated.height !== undefined && migrated.h === undefined) migrated.h = migrated.height;
    next[key] = { ...(next[key] || {}), ...migrated };
  });
  next.theme = { ...THEMES.midnight, ...(config?.theme || {}) };
  return next;
}

function applyElementAppearance(el, style = {}, theme = THEMES.midnight) {
  el.style.background = style.background || theme.panel || '';
  el.style.color = style.color || theme.text || '';
  el.style.borderColor = style.borderColor || theme.border || '';
  el.style.borderRadius = `${style.radius ?? ''}${style.radius === undefined ? '' : 'px'}`;
  el.style.opacity = style.opacity ?? (layoutConfig[el.dataset.key]?.visible === false ? .25 : 1);
  const textColor = style.color || theme.text || '';
  const accentColor = style.accent || textColor;
  // Son gol bandı tek satırlıdır; okunabilir kalması için aşırı büyümeyi sınırla.
  const scale = el.dataset.key === 'lastGoal' ? Math.min(style.fontScale ?? 1, 1.35) : (style.fontScale ?? 1);
  el.querySelectorAll('*').forEach(child => {
    if (!child.dataset.editorBaseFont) child.dataset.editorBaseFont = getComputedStyle(child).fontSize;
    const base = parseFloat(child.dataset.editorBaseFont);
    if (base) child.style.fontSize = `${base * scale}px`;
    child.style.color = textColor;
    child.style.fontFamily = style.fontFamily && style.fontFamily !== 'inherit' ? style.fontFamily : '';
    child.style.fontWeight = style.fontWeight && style.fontWeight !== 'inherit' ? style.fontWeight : '';
    child.style.letterSpacing = style.letterSpacing !== undefined ? `${style.letterSpacing}px` : '';
    child.style.lineHeight = style.lineHeight ?? '';
    child.style.textAlign = style.textAlign || 'center';
    child.style.textShadow = style.textShadow === false ? 'none' : '';
  });
  el.style.textAlign = style.textAlign || 'center';
  // Sayısal skor, sayaç ve durum göstergeleri ayrı vurgu rengi kullanır.
  el.querySelectorAll('.score-number, .score-separator, .timer-display, .period-indicator, .card-badge').forEach(child => { child.style.color = accentColor; });
  const previewLogo = el.querySelector('.team-logo-wrapper');
  if (previewLogo) previewLogo.style.transform = `scale(${style.logoScale ?? 1})`;
  applyTeamInnerAppearance(el, style.inner || {});
  applyScoreInnerAppearance(el, style.inner || {});
  applyGenericInnerAppearance(el, style.inner || {});
}

function teamInnerNode(el, part) {
  const selector = { logo: '.team-logo-wrapper', name: '.team-name', yellow: '.yellow-badge', red: '.red-badge' }[part];
  return selector ? el?.querySelector(selector) : null;
}

function applyTeamInnerAppearance(el, inner) {
  ['logo', 'name', 'yellow', 'red'].forEach(part => {
    const node = teamInnerNode(el, part); const style = inner[part] || {};
    if (!node) return;
    const legacyLogoScale = layoutConfig[el.dataset.key]?.style?.logoScale ?? 1;
    const scale = Number(style.scale ?? (part === 'logo' ? legacyLogoScale : 1));
    if (style.w !== undefined) {
      // Kart rozetleri de artık üst kapsayıcı yerine doğrudan takım kartına göre konumlanır.
      el.classList.add('team-custom-layout');
      node.style.position = 'absolute';
      node.style.left = `${style.x}%`; node.style.top = `${style.y}%`;
      node.style.width = `${style.w}%`; node.style.height = `${style.h}%`;
      node.style.zIndex = '3';
      node.style.transform = `scale(${scale})`;
    }
    else node.style.transform = `translate(${Number(style.x || 0)}%, ${Number(style.y || 0)}%) scale(${scale})`;
    if (style.color && part !== 'logo') { node.style.color = style.color; node.querySelectorAll('*').forEach(child => child.style.color = style.color); }
    if (style.background) node.style.background = style.background;
  });
}

function applyScoreInnerAppearance(el, inner) {
  const nodes = { homeScore: el.querySelector('.score-home'), separator: el.querySelector('.score-separator'), awayScore: el.querySelector('.score-away') };
  Object.entries(nodes).forEach(([part, node]) => { const style = inner[part] || {}; if (!node) return; if (style.w !== undefined) { el.classList.add('score-custom-layout'); node.style.left=`${style.x}%`; node.style.top=`${style.y}%`; node.style.width=`${style.w}%`; node.style.height=`${style.h}%`; node.style.transform=`scale(${style.scale ?? 1})`; } });
}

function applyGenericInnerAppearance(el, inner) {
  const selectors = GENERIC_INNER_SELECTORS[el.dataset.key] || {};
  Object.entries(selectors).forEach(([part, selector]) => { const node = el.querySelector(selector); const style = inner[part] || {}; if (!node || style.w === undefined) return; node.style.position='absolute'; node.style.left=`${style.x}%`; node.style.top=`${style.y}%`; node.style.width=`${style.w}%`; node.style.height=`${style.h}%`; node.style.margin='0'; node.style.display='flex'; node.style.alignItems='center'; node.style.justifyContent='center'; node.style.transform=`scale(${style.scale ?? 1})`; });
}

function populateTeamInnerControls() {
  if (!selectedElement || !['teamHome', 'teamAway'].includes(selectedElement.dataset.key)) return;
  const part = document.getElementById('innerPart').value;
  const style = layoutConfig[selectedElement.dataset.key].style ||= {};
  const inner = ensureTeamInnerConfig(selectedElement); const values = inner[part] || {};
  document.getElementById('innerX').value = values.x ?? 0; document.getElementById('innerY').value = values.y ?? 0;
  document.getElementById('innerScale').value = Math.round((values.scale ?? 1) * 100);
  document.getElementById('innerColor').value = values.color || '#ffffff'; document.getElementById('innerBackground').value = values.background || '#0f172a';
  document.getElementById('innerXOut').textContent = document.getElementById('innerX').value;
  document.getElementById('innerYOut').textContent = document.getElementById('innerY').value;
  document.getElementById('innerScaleOut').textContent = document.getElementById('innerScale').value;
}

function selectTeamInnerPart() { populateTeamInnerControls(); }

function updateTeamInner(property) {
  if (!selectedElement || !['teamHome', 'teamAway'].includes(selectedElement.dataset.key)) return;
  const inner = ensureTeamInnerConfig(selectedElement); const part = document.getElementById('innerPart').value; const values = inner[part] ||= {};
  const control = { x: 'innerX', y: 'innerY', scale: 'innerScale', color: 'innerColor', background: 'innerBackground' }[property];
  let value = document.getElementById(control).value;
  if (property === 'x' || property === 'y') { value = Number(value); document.getElementById(`${control}Out`).textContent = value; }
  if (property === 'scale') { value = Number(value) / 100; document.getElementById('innerScaleOut').textContent = Math.round(value * 100); }
  values[property] = value; applyTeamInnerAppearance(selectedElement, inner); markDirty(); recordHistory();
}

function updateAppearance(property) {
  if (!selectedElement) return;
  const key = selectedElement.dataset.key;
  const style = layoutConfig[key].style ||= {};
  const values = { background: 'propBackground', color: 'propColor', accent: 'propAccent', border: 'propBorder', radius: 'propRadius', opacity: 'propOpacity', fontScale: 'propFontScale', logoScale: 'propLogoScale', logoFit: 'propLogoFit', fontFamily: 'propFontFamily', fontWeight: 'propFontWeight', letterSpacing: 'propLetterSpacing', lineHeight: 'propLineHeight', textAlign: 'propTextAlign', textShadow: 'propTextShadow' };
  let value = document.getElementById(values[property]).value;
  if (property === 'radius') { value = Number(value); document.getElementById('propRadiusOut').textContent = value; }
  if (property === 'opacity') { value = Number(value) / 100; document.getElementById('propOpacityOut').textContent = Math.round(value * 100); }
  if (property === 'fontScale') { value = Number(value) / 100; document.getElementById('propFontScaleOut').textContent = Math.round(value * 100); }
  if (property === 'logoScale') { value = Number(value) / 100; document.getElementById('propLogoScaleOut').textContent = Math.round(value * 100); }
  if (property === 'letterSpacing') { value = Number(value); document.getElementById('propLetterSpacingOut').textContent = value; }
  if (property === 'lineHeight') { value = Number(value) / 100; document.getElementById('propLineHeightOut').textContent = Math.round(value * 100); }
  if (property === 'textShadow') value = document.getElementById('propTextShadow').checked;
  style[property === 'border' ? 'borderColor' : property] = value;
  applyElementAppearance(selectedElement, style, layoutConfig.theme);
  markDirty();
}

function updateTheme(property) { layoutConfig.theme ||= {}; const id = `theme${property[0].toUpperCase()}${property.slice(1)}`; layoutConfig.theme[property] = document.getElementById(id).value; applyToPreview(); markDirty(); recordHistory(); }
function applyTheme(name) { layoutConfig.theme = { ...THEMES[name] }; applyToPreview(); markDirty(); recordHistory(); showToast('✨ Tema uygulandı', 'success'); }
function updateThemeInputs() { const theme = layoutConfig.theme || THEMES.midnight; if (!document.getElementById('themeBackground')) return; ['background', 'panel', 'text', 'accent', 'border'].forEach(property => { document.getElementById(`theme${property[0].toUpperCase()}${property.slice(1)}`).value = theme[property] || THEMES.midnight[property]; }); }
function changeLayer(direction) { if (!selectedElement) return; const key = selectedElement.dataset.key; layoutConfig[key].z = clamp((layoutConfig[key].z || 2) + direction, 1, 20); selectedElement.style.zIndex = layoutConfig[key].z; markDirty(); recordHistory(); }
function alignSelected(where) { if (!selectedElement) return; const c = document.getElementById('previewContainer'); const el = selectedElement; let x = el.offsetLeft / c.offsetWidth * 100, y = el.offsetTop / c.offsetHeight * 100; const w = el.offsetWidth / c.offsetWidth * 100, h = el.offsetHeight / c.offsetHeight * 100; if (where === 'left') x=0; if (where === 'center') x=(100-w)/2; if (where === 'right') x=100-w; if (where === 'top') y=0; if (where === 'middle') y=(100-h)/2; if (where === 'bottom') y=100-h; el.style.left=`${round1(x)}%`; el.style.top=`${round1(y)}%`; updatePropsPanel(el); syncConfigFromDOM(); markDirty(); recordHistory(); }
function nudgeSelected(key, step) { const c = document.getElementById('previewContainer'); const el = selectedElement; const x = el.offsetLeft / c.offsetWidth * 100, y = el.offsetTop / c.offsetHeight * 100; el.style.left = `${round1(x + (key==='ArrowRight'?step:key==='ArrowLeft'?-step:0))}%`; el.style.top = `${round1(y + (key==='ArrowDown'?step:key==='ArrowUp'?-step:0))}%`; syncConfigFromDOM(); updatePropsPanel(el); markDirty(); recordHistory(); }
function snap(value, total) { return Math.round((value / total * 100) / 2) * 2 / 100 * total; }
function markDirty() { const state = document.getElementById('saveState'); if (state) state.textContent = 'Kaydedilmemiş değişiklikler'; }
function recordHistory(reset = false) { if (isApplyingHistory) return; const state = JSON.stringify(layoutConfig); if (reset) { history = [state]; historyIndex = 0; } else if (history[historyIndex] !== state) { history.splice(historyIndex + 1); history.push(state); historyIndex = history.length - 1; if (history.length > 50) { history.shift(); historyIndex--; } } updateHistoryButtons(); }
function undo() { if (historyIndex <= 0) return; isApplyingHistory=true; layoutConfig=JSON.parse(history[--historyIndex]); applyToPreview(); if(selectedElement) updatePropsPanel(selectedElement); isApplyingHistory=false; updateHistoryButtons(); markDirty(); }
function redo() { if (historyIndex >= history.length-1) return; isApplyingHistory=true; layoutConfig=JSON.parse(history[++historyIndex]); applyToPreview(); if(selectedElement) updatePropsPanel(selectedElement); isApplyingHistory=false; updateHistoryButtons(); markDirty(); }
function updateHistoryButtons() { document.getElementById('undoBtn').disabled = historyIndex <= 0; document.getElementById('redoBtn').disabled = historyIndex >= history.length - 1; }
function rgbToHex(value, fallback) { const match = value?.match(/\d+/g); return match?.length >= 3 ? '#' + match.slice(0,3).map(v => Number(v).toString(16).padStart(2,'0')).join('') : fallback; }
async function deleteLayout() { if (!currentLayout) return showToast('Silinecek kayıtlı bir tasarım yok', 'warning'); if (!confirm(`“${currentLayout.name}” tasarımını silmek istiyor musunuz?`)) return; const res = await API.delete(`/layouts/${currentLayout.id}`); if (!res.success) return showToast(res.message || 'Tasarım silinemedi', 'warning'); showToast('Tasarım silindi', 'success'); newLayout(); await loadLayouts(); }

// ============================================================
// TOAST
// ============================================================
function showToast(msg, type = 'info') {
  document.getElementById('editorToast')?.remove();
  const t = document.createElement('div');
  t.id = 'editorToast';
  t.className = `editor-toast editor-toast-${type}`;
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => { t.classList.add('editor-toast-fade'); setTimeout(() => t.remove(), 400); }, 2500);
}
