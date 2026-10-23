'use strict';

const net = require('node:net');

const host = '127.0.0.1';
const port = Number(process.env.SMTP_PORT || 1025);
if (!Number.isInteger(port) || port < 1 || port > 65535) {
  throw new Error('SMTP_PORT должен быть от 1 до 65535.');
}

const server = net.createServer((socket) => {
  socket.setEncoding('utf8');
  socket.write('220 localhost Lab06 SMTP capture ready\r\n');
  let buffer = '';
  let dataMode = false;
  let dataLines = [];

  function respond(line) { socket.write(line + '\r\n'); }
  function processLine(line) {
    if (dataMode) {
      if (line === '.') {
        const contents = dataLines.join('\n');
        console.log('\n========== SMTP ПИСЬМО (локально) ==========\n' + contents +
          '\n========== КОНЕЦ ПИСЬМА ==========\n');
        dataLines = [];
        dataMode = false;
        respond('250 2.0.0 Message captured locally');
      } else {
        dataLines.push(line.startsWith('..') ? line.slice(1) : line);
      }
      return;
    }
    const command = line.split(' ')[0].toUpperCase();
    switch (command) {
      case 'EHLO':
        socket.write('250-localhost\r\n250-8BITMIME\r\n250 SIZE 1048576\r\n');
        break;
      case 'HELO':
      case 'MAIL':
      case 'RCPT':
      case 'RSET':
      case 'NOOP':
        respond('250 2.0.0 OK');
        break;
      case 'DATA':
        dataMode = true;
        respond('354 End data with <CRLF>.<CRLF>');
        break;
      case 'QUIT':
        respond('221 2.0.0 Bye');
        socket.end();
        break;
      default:
        respond('502 5.5.1 Command not implemented');
    }
  }

  socket.on('data', (chunk) => {
    buffer += chunk;
    let newline;
    while ((newline = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, newline).replace(/\r$/, '');
      buffer = buffer.slice(newline + 1);
      processLine(line);
    }
  });
  socket.on('error', (err) => console.warn('SMTP socket:', err.message));
});

server.listen(port, host, () => {
  console.log(`Локальный SMTP-приёмник: ${host}:${port}`);
  console.log('Режим безопасной демонстрации: письма будут показаны здесь и НЕ уйдут в интернет.');
});
