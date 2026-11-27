const WebSocket = require("ws");

const server = new WebSocket.Server({ port: 4000 });
server.on("connection", (socket) => {
  console.log("клиент подключен");
  socket.on("message", (message) => {
    const text = message.toString();
    console.log(text);
    for (const client of server.clients) {
      if (client.readyState === WebSocket.OPEN) client.send(text);
    }
  });
  socket.on("close", () => console.log("клиент отключен"));
});
server.on("listening", () => console.log("широковещательный WS-сервер: ws://localhost:4000"));
