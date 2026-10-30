// Deliberately narrow local endpoint for a temporary HTTPS tunnel. It accepts
// only the payment provider's form callback and forwards it to the application.
const http = require('http');

const host = '127.0.0.1';
const port = Number(process.env.PAYMENT_CALLBACK_PROXY_PORT || 18085);

http.createServer((request, response) => {
    // Browsers request this automatically after rendering the callback result.
    // Return an empty success response without exposing a static-file route.
    if (request.method === 'GET' && request.url === '/favicon.ico') {
        response.writeHead(204);
        return response.end();
    }
    if (request.method !== 'POST' || request.url !== '/api/payment/callback') {
        response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
        return response.end('Not found');
    }

    let size = 0;
    const parts = [];
    request.on('data', chunk => {
        size += chunk.length;
        if (size > 1024 * 100) request.destroy();
        else parts.push(chunk);
    });
    request.on('end', () => {
        const forward = http.request({
            host: '127.0.0.1', port: 8085, path: '/api/payment/callback', method: 'POST',
            headers: { 'Content-Type': request.headers['content-type'] || 'application/x-www-form-urlencoded', 'Content-Length': size }
        }, upstream => {
            response.writeHead(upstream.statusCode || 502, { 'Content-Type': upstream.headers['content-type'] || 'text/plain; charset=utf-8' });
            upstream.pipe(response);
        });
        forward.on('error', () => { response.writeHead(502); response.end('Payment callback unavailable'); });
        forward.end(Buffer.concat(parts));
    });
}).listen(port, host, () => console.log(`Payment callback proxy listening on ${host}:${port}`));
