"use strict";

const http = require("node:http");

function createServer(directory = "static") {
  const { createStaticHandler } = require("./m07-01")({ path: directory });
  const server = http.createServer(createStaticHandler());
  const rejectSpecialMethod = (_req, socket) => {
    socket.end(
      "HTTP/1.1 405 Method Not Allowed\r\nAllow: GET\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
    );
  };
  server.on("connect", rejectSpecialMethod);
  server.on("upgrade", rejectSpecialMethod);
  return server;
}

if (require.main === module) {
  const port = process.env.PORT || 3000;
  const directory = process.env.STATIC_DIR || "static";
  createServer(directory).listen(port, () => {
    console.log(`Сервер запущен на порту ${port}`);
  });
}

module.exports = { createServer };
