const http = require('http');

const PORT = 5000;

const server = http.createServer((req, res) => {

    if (req.url === '/api/name' && req.method === 'GET') {

        res.writeHead(200, {
            'Content-Type': 'text/plain; charset=utf-8'
        });

        res.end('Лавшук Станислав Александрович');

    } else {

        res.writeHead(404, {
            'Content-Type': 'text/plain; charset=utf-8'
        });

        res.end('404 Not Found');
    }
});

server.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});