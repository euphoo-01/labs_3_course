const WebSocket = require("ws");

const socket = new WebSocket("ws://localhost:4000");
let messageNumber = 0;
let sendTimer;

socket.on("open", () => {
  const sendMessage = () => {
    if (socket.readyState === WebSocket.OPEN) socket.send(`10-03a-client: ${++messageNumber}`);
  };
  sendMessage();
  sendTimer = setInterval(sendMessage, 3000);
});
socket.on("message", (message) => console.log(message.toString()));
socket.on("error", console.error);
socket.on("close", () => clearInterval(sendTimer));
