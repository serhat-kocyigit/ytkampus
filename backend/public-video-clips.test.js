const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const express = require('express');
const { registerPublicVideoClips } = require('./public-video-clips');

test('guest clips: bounded generation, capability downloads, expiry and withdrawn video', async t => {
    const fixture = await fs.mkdtemp(path.join(os.tmpdir(), 'yt-clip-test-'));
    await fs.writeFile(path.join(fixture, 'fixture.mp4'), 'synthetic video');
    const app = express();
    app.use(express.json());
    let clock = Date.now();
    let published = true;
    let rendered = 0;
    const clips = registerPublicVideoClips(app, {
        uploadsDir: fixture,
        now: () => clock,
        getPublicVideo: async id => published && id === 7 ? { id, video_url: '/uploads/fixture.mp4' } : null,
        render: async (input, output, start, end) => {
            assert.equal(await fs.readFile(input, 'utf8'), 'synthetic video');
            assert.equal(start, 1);
            assert.equal(end, 3);
            rendered++;
            await fs.writeFile(output, 'synthetic clipped video');
        },
    });
    const server = app.listen(0, '127.0.0.1');
    await new Promise(resolve => server.once('listening', resolve));
    const base = `http://127.0.0.1:${server.address().port}`;
    t.after(async () => {
        server.closeAllConnections();
        await new Promise(resolve => server.close(resolve));
        await clips.close();
        await fs.unlink(path.join(fixture, 'fixture.mp4'));
        await fs.rmdir(fixture);
    });
    const post = body => fetch(base + '/api/videos/public-clips', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    for (const range of [[-1, 3], [1, 1], [1, 302], [null, 3]]) {
        assert.equal((await post({ video_id: 7, start: range[0], end: range[1] })).status, 400);
    }
    assert.equal(rendered, 0);
    assert.equal((await post({ video_id: 999, start: 1, end: 3 })).status, 404);
    const response = await post({ video_id: 7, start: 1, end: 3 });
    assert.equal(response.status, 200);
    const clip = await response.json();
    assert.equal(clip.success, true);
    const file = await fetch(base + clip.clip_url);
    assert.equal(file.status, 200);
    assert.match(file.headers.get('content-disposition'), /attachment.*Mac_Kesiti\.mp4/);
    assert.equal(file.headers.get('cache-control'), 'no-store');
    assert.equal(await file.text(), 'synthetic clipped video');
    assert.equal((await fetch(base + clip.clip_url.split('?')[0])).status, 404);
    assert.equal((await fetch(base + clip.clip_url.replace(/ticket=.*/, 'ticket=' + '0'.repeat(64)))).status, 404);
    // An existing legacy clip filename cannot be fetched through this endpoint.
    assert.equal((await fetch(base + '/api/videos/public-clips/kesit_existing.mp4/content')).status, 404);
    published = false;
    assert.equal((await fetch(base + clip.clip_url)).status, 404);
    published = true;
    clock += 10 * 60 * 1000 + 1;
    assert.equal((await fetch(base + clip.clip_url)).status, 404);
    assert.equal(rendered, 1);
});
