const WebSocket = require("ws");

const socket = new WebSocket("ws://localhost:4000");
let clientNumber = 0;
let sendTimer;

socket.on("open", () => {
  const sendMessage = () => {
    if (socket.readyState === WebSocket.OPEN) socket.send(`10-01-client: ${++clientNumber}`);
  };
  sendMessage();
  sendTimer = setInterval(sendMessage, 3000);
  setTimeout(() => {
    clearInterval(sendTimer);
    socket.close();
  }, 25000);
});
socket.on("message", (message) => console.log(message.toString()));
socket.on("error", console.error);
socket.on("close", () => {
  clearInterval(sendTimer);
  console.log("соединение закрыто");
});
