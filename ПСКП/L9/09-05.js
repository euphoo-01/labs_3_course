const http = require("http");
const data =
  '<request id="28"><x value="1"/><x value="2"/><m value="a"/><m value="b"/><m value="c"/></request>';
const req = http.request(
  "http://localhost:3000/09-05",
  {
    method: "POST",
    headers: {
      "Content-Type": "application/xml",
      "Content-Length": Buffer.byteLength(data),
    },
  },
  (res) => {
    console.log("Статус:", res.statusCode);
    let body = "";
    res.setEncoding("utf8");
    res.on("data", (chunk) => (body += chunk));
    res.on("end", () => console.log("Тело ответа:", body));
  },
);
req.on("error", console.error);
req.end(data);
