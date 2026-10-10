let http = require('http');
let url = require('url');
let path = require('path');
let readline = require('readline');
let fs = require('fs');
let DB = require('./db.js');

let PORT = 5000;
let db = new DB();

let shutdownTimer = null;
let commitTimer = null;
let statisticsTimer = null;
let isCollectingStats = false;
let statistics = {
    start: '',
    finish: '',
    request: 0,
    commit: 0
};

function sendJson(response, status, data) {
    response.writeHead(status, {
        'Content-Type': 'application/json; charset=utf-8'
    });
    response.end(JSON.stringify(data));
}

function readJson(request, callback) {
    let body = '';

    request.on('data', (chunk) => {
        body += chunk;
    });

    request.on('end', () => {
        try {
            let row = JSON.parse(body);
            if (row === null || typeof row !== 'object' || Array.isArray(row)) {
                throw new Error('Expected a JSON object');
            }
            callback(null, row);
        }
        catch (error) {
            callback(error);
        }
    });
}

function stopStatistics() {
    if (statisticsTimer !== null) {
        clearTimeout(statisticsTimer);
        statisticsTimer = null;
    }

    if (isCollectingStats) {
        statistics.finish = new Date().toISOString();
        isCollectingStats = false;
        console.log('Statistics collection stopped');
    }
}

function startStatistics(seconds) {
    stopStatistics();

    statistics = {
        start: new Date().toISOString(),
        finish: '',
        request: 0,
        commit: 0
    };
    isCollectingStats = true;

    statisticsTimer = setTimeout(stopStatistics, seconds * 1000);
    statisticsTimer.unref();

    console.log('Statistics collection started for ' + seconds + ' s');
}

function stopCommits() {
    if (commitTimer !== null) {
        clearInterval(commitTimer);
        commitTimer = null;
    }
}

function startCommits(seconds) {
    stopCommits();

    commitTimer = setInterval(() => {
        db.emit('COMMIT');
    }, seconds * 1000);
    commitTimer.unref();

    console.log('Automatic COMMIT every ' + seconds + ' s');
}

db.on('GET', (request, response) => {
    console.log('DB.GET');
    sendJson(response, 200, db.select());
});

db.on('POST', (request, response) => {
    console.log('DB.POST');

    readJson(request, (error, row) => {
        if (error) {
            sendJson(response, 400, { error: 'Invalid JSON object' });
            return;
        }

        row.id = Number(row.id);
        let inserted = db.insert(row);
        sendJson(response, 200, inserted);
    });
});

db.on('PUT', (request, response) => {
    console.log('DB.PUT');

    readJson(request, (error, row) => {
        if (error) {
            sendJson(response, 400, { error: 'Invalid JSON object' });
            return;
        }

        row.id = Number(row.id);
        let updated = db.update(row);

        if (updated === null) {
            sendJson(response, 404, { error: 'Row not found' });
            return;
        }

        sendJson(response, 200, updated);
    });
});

db.on('DELETE', (request, response) => {
    console.log('DB.DELETE');

    let query = url.parse(request.url, true).query;
    let deleted = db.delete(Number(query.id));

    if (deleted === null) {
        sendJson(response, 404, { error: 'Row not found' });
        return;
    }

    sendJson(response, 200, deleted);
});

db.on('COMMIT', () => {
    db.commit();
    console.log('DB.COMMIT');

    if (isCollectingStats) {
        statistics.commit++;
    }
});

let server = http.createServer((request, response) => {
    if (isCollectingStats) {
        statistics.request++;
    }

    let pathname = url.parse(request.url).pathname;

    if (pathname === '/' && request.method === 'GET') {
        fs.readFile(path.join(__dirname, 'idx.html'), (error, data) => {
            if (error) {
                sendJson(response, 500, { error: 'Cannot read idx.html' });
                return;
            }

            response.writeHead(200, {
                'Content-Type': 'text/html; charset=utf-8'
            });
            response.end(data);
        });
    }
    else if (pathname === '/api/ss' && request.method === 'GET') {
        sendJson(response, 200, statistics);
    }
    else if (pathname === '/api/db') {
        if (['GET', 'POST', 'PUT', 'DELETE'].includes(request.method)) {
            db.emit(request.method, request, response);
        }
        else {
            sendJson(response, 405, { error: 'Method not allowed' });
        }
    }
    else {
        sendJson(response, 404, { error: 'Not found' });
    }
});

let input = readline.createInterface({ input: process.stdin });

function shutdownServer() {
    console.log('Shutting down server...');
    stopCommits();
    stopStatistics();
    input.close();
    process.stdin.pause();

    server.close(() => {
        console.log('Server stopped');
    });
}

function secondsFromArgument(value) {
    let seconds = Number(value);
    if (!Number.isFinite(seconds) || seconds <= 0 || seconds * 1000 > 2147483647) {
        return null;
    }
    return seconds;
}

input.on('line', (line) => {
    let parts = line.trim().split(/\s+/);
    let command = parts[0];

    if (command !== 'sd' && command !== 'sc' && command !== 'ss') {
        console.log('Available commands: sd [seconds], sc [seconds], ss [seconds]');
        return;
    }

    if (parts.length > 2) {
        console.log('Usage: ' + command + ' [seconds]');
        return;
    }

    if (parts.length === 1) {
        if (command === 'sd') {
            if (shutdownTimer !== null) {
                clearTimeout(shutdownTimer);
                shutdownTimer = null;
            }
            console.log('Scheduled shutdown cancelled');
        }
        else if (command === 'sc') {
            stopCommits();
            console.log('Automatic COMMIT stopped');
        }
        else {
            stopStatistics();
        }
        return;
    }

    let seconds = secondsFromArgument(parts[1]);
    if (seconds === null) {
        console.log('Seconds must be a positive number');
        return;
    }

    if (command === 'sd') {
        if (shutdownTimer !== null) {
            clearTimeout(shutdownTimer);
        }
        shutdownTimer = setTimeout(shutdownServer, seconds * 1000);
        shutdownTimer.ref();
        console.log('Server shutdown scheduled in ' + seconds + ' s');
    }
    else if (command === 'sc') {
        startCommits(seconds);
    }
    else {
        startStatistics(seconds);
    }
});

server.listen(PORT, () => {
    console.log('Server running at http://localhost:' + PORT + '/');
});
