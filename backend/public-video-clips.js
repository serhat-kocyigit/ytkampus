const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawn } = require('node:child_process');

const TTL = 10 * 60 * 1000;
const MAX_BYTES = 100 * 1024 * 1024;
// İndirilen dosyada görünür, ancak oyunu kapatmayan merkez filigranı.
// Alpha değeri yavaşça değişerek statik ve sert bir yazı hissi oluşturmaz.
const WATERMARK_FILTER = "drawtext=fontfile=/usr/share/fonts/TTF/DejaVuSans.ttf:text='YT Kampüs':fontcolor=white:fontsize=h/18:x=(w-text_w)/2:y=(h-text_h)/2:alpha=0.14+0.04*sin(t*2):shadowcolor=black@0.18:shadowx=2:shadowy=2";

function runMediaTool(command, args, timeoutMs) {
    return new Promise((resolve, reject) => {
        const child = spawn(command, args, { shell: false, windowsHide: true });
        let output = '';
        const timer = setTimeout(() => child.kill('SIGKILL'), timeoutMs);
        child.stdout.on('data', chunk => { output = (output + chunk).slice(-8192); });
        child.stderr.on('data', () => {});
        child.once('error', error => { clearTimeout(timer); reject(error); });
        child.once('close', code => {
            clearTimeout(timer);
            code === 0 ? resolve(output) : reject(new Error('Video işlenemedi'));
        });
    });
}

async function renderClip(input, output, start, end) {
    const duration = Number(await runMediaTool('ffprobe', [
        '-v', 'error', '-show_entries', 'format=duration', '-of',
        'default=noprint_wrappers=1:nokey=1', input,
    ], 10000));
    if (!Number.isFinite(duration) || end > duration + 0.1) {
        const error = new Error('Kesit aralığı videonun süresini aşamaz.');
        error.status = 400;
        throw error;
    }
    await runMediaTool('ffmpeg', [
        '-nostdin', '-v', 'error', '-ss', String(start), '-i', input,
        '-t', String(end - start), '-map', '0:v:0', '-map', '0:a:0?',
        '-vf', WATERMARK_FILTER, '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22',
        '-c:a', 'aac', '-b:a', '128k', '-avoid_negative_ts', 'make_zero', '-movflags', '+faststart',
        '-fs', String(MAX_BYTES), output,
    ], 180000);
    const stat = await fs.stat(output);
    if (stat.size < 100 || stat.size >= MAX_BYTES) throw new Error('Kesit boyutu uygun değil');
}

// Only NEW clips of already-public recordings use this short-lived workflow.
// Existing owner-bound video_clips records and their authenticated routes are
// deliberately not used here. No anonymous database owner or user is created.
function registerPublicVideoClips(app, { getPublicVideo, uploadsDir, render = renderClip, now = Date.now }) {
    const entries = new Map();
    const attempts = new Map();
    const directory = fs.mkdtemp(path.join(os.tmpdir(), 'yt-public-clips-'));
    let active = 0;
    let pending = 0;

    async function sweep() {
        for (const [id, entry] of entries) {
            if (entry.expires <= now()) {
                entries.delete(id);
                await fs.unlink(entry.file).catch(() => {});
            }
        }
        for (const [key, attempt] of attempts) {
            if (attempt.expires <= now()) attempts.delete(key);
        }
    }
    const timer = setInterval(() => sweep().catch(() => {}), 60000);
    timer.unref();

    app.post('/api/videos/public-clips', async (req, res) => {
        const videoId = Number(req.body?.video_id);
        const start = Number(req.body?.start);
        const end = Number(req.body?.end);
        if (!Number.isSafeInteger(videoId) || videoId <= 0 ||
            typeof req.body?.start !== 'number' || typeof req.body?.end !== 'number' ||
            !Number.isFinite(start) || !Number.isFinite(end) || start < 0 || end <= start || end - start > 300) {
            return res.status(400).json({ error: 'Geçerli bir video ve en fazla 5 dakikalık kesit seçin.' });
        }
        const key = req.ip;
        const attempt = attempts.get(key);
        if (attempt && attempt.expires > now() && attempt.count >= 6) {
            res.set('Retry-After', String(Math.ceil((attempt.expires - now()) / 1000)));
            return res.status(429).json({ error: 'Çok fazla kesit istendi. Biraz sonra tekrar deneyin.' });
        }
        attempts.set(key, attempt && attempt.expires > now()
            ? { ...attempt, count: attempt.count + 1 }
            : { count: 1, expires: now() + 15 * 60 * 1000 });
        // Reserve capacity before the first await, including pending DB reads.
        if (active >= 2 || entries.size + pending >= 24) {
            res.set('Retry-After', '30');
            return res.status(429).json({ error: 'Kesitler hazırlanıyor. Biraz sonra tekrar deneyin.' });
        }
        active++;
        pending++;
        let output;
        try {
            const video = await getPublicVideo(videoId);
            if (!video) return res.status(404).json({ error: 'Video bulunamadı.' });
            const input = path.resolve(uploadsDir, path.basename(video.video_url));
            if (!input.startsWith(path.resolve(uploadsDir) + path.sep)) throw new Error('Geçersiz dosya');
            await fs.access(input);
            const id = crypto.randomUUID();
            const ticket = crypto.randomBytes(32).toString('hex');
            output = path.join(await directory, `${id}.mp4`);
            await render(input, output, start, end);
            if (res.destroyed) throw new Error('İstek iptal edildi');
            const expires = now() + TTL;
            entries.set(id, { videoId, file: output, ticket, expires });
            res.set('Cache-Control', 'no-store');
            res.json({ success: true, expires_at: new Date(expires).toISOString(),
                clip_url: `/api/videos/public-clips/${id}/content?ticket=${ticket}` });
        } catch (error) {
            if (output) await fs.unlink(output).catch(() => {});
            if (!res.headersSent && !res.destroyed) res.status(error.status || 500).json({
                error: error.status === 400 ? error.message : 'Kesit hazırlanamadı. Lütfen tekrar deneyin.',
            });
        } finally { active--; pending--; }
    });

    app.get('/api/videos/public-clips/:id/content', async (req, res) => {
        res.set('Cache-Control', 'no-store');
        res.set('Referrer-Policy', 'no-referrer');
        const entry = entries.get(req.params.id);
        const ticket = String(req.query.ticket || '');
        if (!entry || entry.expires <= now() || !/^[0-9a-f]{64}$/.test(ticket) ||
            !crypto.timingSafeEqual(Buffer.from(ticket), Buffer.from(entry.ticket))) {
            return res.status(404).json({ error: 'İndirme bağlantısı geçersiz veya süresi dolmuş. Kesiti yeniden hazırlayın.' });
        }
        try {
            if (!await getPublicVideo(entry.videoId)) return res.status(404).json({ error: 'Video artık erişime açık değil.' });
            res.download(entry.file, 'Mac_Kesiti.mp4', error => {
                if (error && !res.headersSent) res.status(404).end();
            });
        } catch { res.status(500).json({ error: 'Kesit indirilemedi.' }); }
    });

    return { close: async () => {
        clearInterval(timer);
        // The directory is created by this module and contains only its clips.
        for (const entry of entries.values()) await fs.unlink(entry.file).catch(() => {});
        await fs.rmdir(await directory).catch(() => {});
    } };
}

module.exports = { registerPublicVideoClips };
