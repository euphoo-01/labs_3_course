var http = require('http');
var url = require('url');

var PORT = 5000;

var state = 'norm';
process.stdin.setEncoding('utf-8');

process.stdin.on('readable', () => {
    var chunk = null;

    while ((chunk = process.stdin.read()) !== null) {
        var command = chunk.trim();

        if (command === 'exit') {
            process.exit(0);
        }

        var oldState = state;

        if (command === 'norm' || command === 'stop' ||
            command === 'test' || command === 'idle') {
            state = command;
            process.stdout.write('reg = ' + oldState + '--> ' + state + '\n');
        }

        process.stdout.write(state + '->');
    }
});

var fact = (n) => {
    return (n < 2 ? 1 : n * fact(n - 1));
};

function FactNextTick(n, cb) {
    this.fn = n;
    this.ffact = fact;
    this.fcb = cb;

    this.calc = () => {
        process.nextTick(() => {
            this.fcb(null, this.ffact(this.fn));
        });
    };
}

function FactImmediate(n, cb) {
    this.fn = n;
    this.ffact = fact;
    this.fcb = cb;

    this.calc = () => {
        setImmediate(() => {
            this.fcb(null, this.ffact(this.fn));
        });
    };
}

function getK(request) {
    var query = url.parse(request.url, true).query;

    if (typeof query.k !== 'undefined') {
        var k = parseInt(query.k);

        if (Number.isInteger(k) && k >= 0) {
            return k;
        }
    }

    return null;
}

function sendJson(response, k, result) {
    response.writeHead(200, {
        'Content-Type': 'application/json; charset=utf-8'
    });

    response.end(JSON.stringify({
        k: k,
        fact: result
    }));
}

function sendBadRequest(response) {
    response.writeHead(400, {
        'Content-Type': 'application/json; charset=utf-8'
    });

    response.end(JSON.stringify({
        error: 'Parameter k must be a non-negative integer'
    }));
}

function createTestPage(title, factPath) {
    return `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width">
    <title>${title}</title>
</head>
<body>
    <h1>${title}</h1>
    <div id="result"></div>

    <script>
        result.innerHTML = '';

        var n = 0;
        var completed = 0;
        const d = Date.now();

        for (var k = 1; k <= 20; k++) {
            fetch('${factPath}?k=' + k, {
                method: 'GET',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                }
            })
            .then((response) => {
                return response.json();
            })
            .then((pdata) => {
                result.innerHTML +=
                    (n++) + '. Результат: ' +
                    (Date.now() - d) + '-' +
                    pdata.k + '/' + pdata.fact + '<br/>';

                completed++;

                if (completed === 20) {
                    result.innerHTML +=
                        '<br/><b>Общая продолжительность: ' +
                        (Date.now() - d) + ' мс</b>';
                }
            });
        }
    </script>
</body>
</html>`;
}

var server = http.createServer(function (request, response) {
    var pathname = url.parse(request.url).pathname;

    if (pathname === '/') {
        response.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8'
        });
        response.end('<h1>' + state + '</h1>');
    }

    else if (pathname === '/fact') {
        var k = getK(request);

        if (k === null) {
            sendBadRequest(response);
        }
        else {
            sendJson(response, k, fact(k));
        }
    }

    else if (pathname === '/sync') {
        response.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8'
        });
        response.end(createTestPage('Задание 03 - обычный факториал', '/fact'));
    }

    else if (pathname === '/fact-nexttick') {
        var kNext = getK(request);

        if (kNext === null) {
            sendBadRequest(response);
        }
        else {
            var nextFact = new FactNextTick(kNext, (err, result) => {
                sendJson(response, kNext, result);
            });

            nextFact.calc();
        }
    }

    else if (pathname === '/nexttick') {
        response.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8'
        });
        response.end(createTestPage('Задание 04 - process.nextTick', '/fact-nexttick'));
    }

    else if (pathname === '/fact-immediate') {
        var kImmediate = getK(request);

        if (kImmediate === null) {
            sendBadRequest(response);
        }
        else {
            var immediateFact = new FactImmediate(kImmediate, (err, result) => {
                sendJson(response, kImmediate, result);
            });

            immediateFact.calc();
        }
    }

    else if (pathname === '/immediate') {
        response.writeHead(200, {
            'Content-Type': 'text/html; charset=utf-8'
        });
        response.end(createTestPage('Задание 05 - setImmediate', '/fact-immediate'));
    }

    else {
        response.writeHead(404, {
            'Content-Type': 'text/plain; charset=utf-8'
        });
        response.end('Not found');
    }
});

server.listen(PORT, () => {
    console.log('\nServer running at http://localhost:' + PORT + '/');
    console.log('Task 01: http://localhost:' + PORT + '/');
    console.log('Task 02: http://localhost:' + PORT + '/fact?k=3');
    console.log('Task 03: http://localhost:' + PORT + '/sync');
    console.log('Task 04: http://localhost:' + PORT + '/nexttick');
    console.log('Task 05: http://localhost:' + PORT + '/immediate');
    process.stdout.write(state + '->');
});
