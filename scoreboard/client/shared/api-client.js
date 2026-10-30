/**
 * REST API Client
 * DÜZELTİLDİ: Tüm metodlarda try/catch — network hatası paneli çökertmez
 */
const API = {
  baseUrl: '/api',

  /** Hata nesnesi döndür */
  _err(e) {
    console.error('[API Error]', e);
    return { success: false, message: e.message || 'Ağ bağlantısı hatası' };
  },

  async _json(res) {
    let payload;
    try { payload = await res.json(); } catch (_) { payload = null; }
    if (!res.ok) return { success: false, message: payload?.message || `HTTP ${res.status}` };
    return payload || { success: false, message: 'Sunucudan geçersiz yanıt alındı' };
  },

  /** GET isteği */
  async get(endpoint) {
    try {
      const res = await fetch(`${this.baseUrl}${endpoint}`);
      return this._json(res);
    } catch (e) { return this._err(e); }
  },

  /** POST isteği */
  async post(endpoint, data) {
    try {
      const res = await fetch(`${this.baseUrl}${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      return this._json(res);
    } catch (e) { return this._err(e); }
  },

  /** PUT isteği */
  async put(endpoint, data) {
    try {
      const res = await fetch(`${this.baseUrl}${endpoint}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
      });
      return this._json(res);
    } catch (e) { return this._err(e); }
  },

  /** DELETE isteği */
  async delete(endpoint) {
    try {
      const res = await fetch(`${this.baseUrl}${endpoint}`, { method: 'DELETE' });
      return this._json(res);
    } catch (e) { return this._err(e); }
  },

  /** FormData ile dosya yükleme */
  async upload(endpoint, formData) {
    try {
      const res = await fetch(`${this.baseUrl}${endpoint}`, {
        method: 'POST',
        body: formData
      });
      return this._json(res);
    } catch (e) { return this._err(e); }
  }
};
