const http = require('http');

const server = http.createServer((req, res) => {
    let body = '';
    req.on('data', chunk => {
        body += chunk.toString();
    });

    req.on('end', () => {
        res.writeHead('200', { "content-type": "text/html" });
        res.end(`
                <h1>Инфа о запросе</h1>
                <p>Метод: ${req.method}</p>
                <p>URI: ${req.url}</p>
                <pre>${JSON.stringify(req.headers, null, 2)}</pre>
                <pre>${body || ''}</pre>
            `)
    });
})

server.listen(3000);
