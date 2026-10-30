// ── ProSaha Global API & Auth Utility ─────────────────────────────────────────
// Same-origin API keeps the app working behind Docker/Nginx and avoids hard-coded hosts.
const API = '/api';

const ProSaha = {
    // Auth helpers
    // Oturum anahtarı HttpOnly çerezde tutulur; JavaScript tarafından okunamaz.
    getToken: () => '',
    getUser: () => { try { return JSON.parse(localStorage.getItem('prosaha_user')); } catch { return null; } },
    setSession: (_token, user) => { localStorage.removeItem('prosaha_token'); localStorage.setItem('prosaha_user', JSON.stringify(user)); },
    clearSession: () => { localStorage.removeItem('prosaha_token'); localStorage.removeItem('prosaha_user'); },
    isLoggedIn: () => !!ProSaha.getUser(),
    isAdmin: () => { const u = ProSaha.getUser(); return u && u.role === 'admin'; },

    // Authenticated fetch
    async fetch(endpoint, options = {}) {
        const token = ProSaha.getToken();
        const headers = { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...(options.headers || {}) };
        const res = await fetch(`${API}${endpoint}`, { ...options, headers, credentials: 'same-origin' });
        const data = await res.json().catch(() => ({ error: 'Sunucudan geçerli yanıt alınamadı' }));
        if (res.status === 401) { ProSaha.clearSession(); window.location.href = '/pages/auth/login.html'; }
        return { ok: res.ok, status: res.status, data };
    },

    // Toast notification
    toast(msg, type = 'success') {
        const t = document.createElement('div');
        t.className = `ps-toast ps-toast-${type}`;
        const icon = document.createElement('span');
        icon.textContent = type === 'success' ? '✓' : '✕';
        t.append(icon, document.createTextNode(` ${String(msg)}`));
        document.body.appendChild(t);
        setTimeout(() => t.classList.add('show'), 10);
        setTimeout(() => { t.classList.remove('show'); setTimeout(() => t.remove(), 400); }, 3500);
    },

    // Format date
    formatDate: (d) => new Date(d).toLocaleDateString('tr-TR', { day: '2-digit', month: 'long', year: 'numeric', weekday: 'long' }),
    formatCurrency: (n) => new Intl.NumberFormat('tr-TR', { style: 'currency', currency: 'TRY' }).format(n),

    // Logout
    async logout() {
        try { await fetch(`${API}/auth/logout`, { method: 'POST', credentials: 'same-origin' }); } catch {}
        ProSaha.clearSession(); window.location.href = '/index.html';
    },

    // Redirect if not logged in
    requireAuth(adminRequired = false) {
        if (!ProSaha.isLoggedIn()) { window.location.href = '/pages/auth/login.html'; return false; }
        if (adminRequired && !ProSaha.isAdmin()) { window.location.href = '/pages/user/dashboard.html'; return false; }
        return true;
    }
};
