const http = require("http");
http
  .get("http://localhost:3000/09-02?x=10&y=2", (res) => {
    console.log("Статус:", res.statusCode);
    let body = "";
    res.setEncoding("utf8");
    res.on("data", (chunk) => (body += chunk));
    res.on("end", () => console.log("Тело ответа:", body));
  })
  .on("error", console.error);
