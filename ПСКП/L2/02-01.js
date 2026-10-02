const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;

const server = http.createServer((req, res) => {

    if (req.url === '/html' && req.method === 'GET') {

        const filePath = path.join(__dirname, 'index.html');

        fs.readFile(filePath, (err, data) => {

            if (err) {
                res.writeHead(500, {
                    'Content-Type': 'text/plain; charset=utf-8'
                });

                res.end('Ошибка чтения файла');
                return;
            }

            res.writeHead(200, {
                'Content-Type': 'text/html; charset=utf-8'
            });

            res.end(data);
        });

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