const http = require("http");
const data = JSON.stringify({
  x: 1,
  y: 2,
  s: "Сообщение",
  m: ["a", "b", "c", "d"],
  o: { surname: "Иванов", name: "Иван" },
});
const req = http.request(
  "http://localhost:3000/09-04",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Content-Length": Buffer.byteLength(data),
    },
  },
  (res) => {
    console.log("Статус:", res.statusCode);
    let body = "";
    res.setEncoding("utf8");
    res.on("data", (chunk) => (body += chunk));
    res.on("end", () => console.log("Тело ответа:", JSON.parse(body)));
  },
);
req.on("error", console.error);
req.end(data);
