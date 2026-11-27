const http = require("http");
const querystring = require("querystring");
const body = querystring.stringify({ x: 10, y: 2, s: "Сообщение" });
const req = http.request(
  "http://localhost:3000/09-03",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
      "Content-Length": Buffer.byteLength(body),
    },
  },
  (res) => {
    console.log("Статус:", res.statusCode);
    let response = "";
    res.setEncoding("utf8");
    res.on("data", (chunk) => (response += chunk));
    res.on("end", () => console.log("Тело ответа:", response));
  },
);
req.on("error", console.error);
req.end(body);
