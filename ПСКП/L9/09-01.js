const http = require("http");
http
  .get("http://localhost:3000/09-01", (res) => {
    console.log("Статус:", res.statusCode);
    console.log("Сообщение:", res.statusMessage);
    console.log("IP-адрес:", res.socket.remoteAddress);
    console.log("Порт:", res.socket.remotePort);
    let body = "";
    res.setEncoding("utf8");
    res.on("data", (chunk) => (body += chunk));
    res.on("end", () => console.log("Тело ответа:", body));
  })
  .on("error", console.error);
