const http = require("http");
const fs = require("fs");
const path = require("path");
const WebSocket = require("ws");

const httpServer = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/start") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    return res.end(fs.readFileSync(path.join(__dirname, "10-01.html")));
  }
  res.writeHead(400, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Bad Request");
});

const wsServer = new WebSocket.Server({ port: 4000 });
wsServer.on("connection", (socket) => {
  let lastClientNumber = 0;
  let serverNumber = 0;
  socket.on("message", (message) => {
    const text = message.toString();
    console.log(text);
    const match = text.match(/^10-01-client: (\d+)$/);
    if (match) lastClientNumber = Number(match[1]);
  });
  const timer = setInterval(() => {
    if (socket.readyState === WebSocket.OPEN) socket.send(`10-01-server: ${lastClientNumber}->${++serverNumber}`);
  }, 5000);
  socket.on("close", () => clearInterval(timer));
});

httpServer.listen(3000, () => console.log("HTTP-сервер: http://localhost:3000/start"));
wsServer.on("listening", () => console.log("WS-сервер: ws://localhost:4000"));
