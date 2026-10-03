var http = require('http');
var url = require('url');
var DB = require('./db.js');
const { readFile } = require('fs');

var PORT = 5000;

var db = new DB();


function sendJson(response, status, data) {
    response.writeHead(status, {
        'Content-Type': 'application/json; charset=utf-8'
    });

    response.end(JSON.stringify(data));
}

function readJson(request, callback) {
    var body = '';

    request.on('data', (chunk) => {
        body += chunk;
    });

    request.on('end', () => {
        try {
            callback(null, JSON.parse(body));
        }
        catch (error) {
            callback(error);
        }
    });
}

db.on('GET', (request, response) => {
    console.log('DB.GET');

    sendJson(response, 200, db.select());
});

db.on('POST', (request, response) => {
    console.log('DB.POST');

    readJson(request, (error, row) => {
        if (error) {
            sendJson(response, 400, {
                error: 'Invalid JSON'
            });
            return;
        }

        row.id = Number(row.id);

        var inserted = db.insert(row);

        sendJson(response, 200, inserted);
    });
});

db.on('PUT', (request, response) => {
    console.log('DB.PUT');

    readJson(request, (error, row) => {
        if (error) {
            sendJson(response, 400, {
                error: 'Invalid JSON'
            });
            return;
        }

        row.id = Number(row.id);

        var updated = db.update(row);

        if (updated === null) {
            sendJson(response, 404, {
                error: 'Row not found'
            });
            return;
        }

        sendJson(response, 200, updated);
    });
});

// DELETE /api/db?id=1
db.on('DELETE', (request, response) => {
    console.log('DB.DELETE');

    var query = url.parse(request.url, true).query;
    var id = Number(query.id);

    var deleted = db.delete(id);

    if (deleted === null) {
        sendJson(response, 404, {
            error: 'Row not found'
        });
        return;
    }

    sendJson(response, 200, deleted);
});

http.createServer(function (request, response) {

    var pathname = url.parse(request.url).pathname;

    if (pathname === '/' && request.method === 'GET') {

        const html = readFile("idx.html", (err, data) => {
            if (err) {
                console.error(err);
            }
            response.writeHead(200, {
                'Content-Type': 'text/html; charset=utf-8'
            });
            response.end(data);
        });

        

        
    }

    else if (pathname === '/api/db') {

        if (
            request.method === 'GET' ||
            request.method === 'POST' ||
            request.method === 'PUT' ||
            request.method === 'DELETE'
        ) {
            db.emit(request.method, request, response);
        }
        else {
            sendJson(response, 405, {
                error: 'Method not allowed'
            });
        }
    }

    else {

        sendJson(response, 404, {
            error: 'Not found'
        });
    }

}).listen(PORT, () => {

    console.log(
        'Server running at http://localhost:' + PORT + '/'
    );

});