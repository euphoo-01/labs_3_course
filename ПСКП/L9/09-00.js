const http = require("http");
const fs = require("fs");
const path = require("path");
const querystring = require("querystring");
const { parseString } = require("xml2js");
const xmlbuilder = require("xmlbuilder");
const multiparty = require("multiparty");

const staticDir = path.join(__dirname, "static");
const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const send = (body, type = "text/plain; charset=utf-8", status = 200) => {
    res.writeHead(status, { "Content-Type": type });
    res.end(body);
  };
  if (req.method === "GET" && url.pathname === "/09-01")
    return send("Ответ GET-запроса");
  if (req.method === "GET" && url.pathname === "/09-02") {
    const x = Number(url.searchParams.get("x"));
    const y = Number(url.searchParams.get("y"));
    if (!Number.isFinite(x) || !Number.isFinite(y))
      return send("Некорректные параметры", undefined, 400);
    return send(String(x + y));
  }
  if (req.method === "POST" && url.pathname === "/09-03") {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      const data = querystring.parse(body);
      send(`${data.x}, ${data.y}, ${data.s}`);
    });
    return;
  }
  if (req.method === "POST" && url.pathname === "/09-04") {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        const data = JSON.parse(body);
        send(
          JSON.stringify({
            __comment: "ответ. лабораторная работа 8/10",
            x_plus_y: data.x + data.y,
            Concatination_s_o: `${data.s}: ${Object.values(data.o).join(", ")}`,
            Length_m: data.m.length,
          }),
          "application/json; charset=utf-8",
        );
      } catch {
        send(
          JSON.stringify({ error: "ошибка json" }),
          "application/json; charset=utf-8",
          400,
        );
      }
    });
    return;
  }
  if (req.method === "POST" && url.pathname === "/09-05") {
    let body = "";
    req.setEncoding("utf8");
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () =>
      parseString(body, (error, data) => {
        if (error || !data.request)
          return send(
            "<error>ошибка xml</error>",
            "application/xml; charset=utf-8",
            400,
          );
        const request = data.request;
        const sum = (request.x || []).reduce(
          (value, item) => value + Number(item.$.value),
          0,
        );
        const concat = (request.m || []).map((item) => item.$.value).join("");
        const xml = xmlbuilder
          .create("response")
          .att("id", "1")
          .att("request", request.$.id);
        xml.ele("sum", { element: "x", result: sum });
        xml.ele("concat", { element: "m", result: concat });
        send(xml.end({ pretty: true }), "application/xml; charset=utf-8");
      }),
    );
    return;
  }
  if (req.method === "POST" && ["/09-06", "/09-07"].includes(url.pathname)) {
    const form = new multiparty.Form({ uploadDir: staticDir });
    form.parse(req, (error, fields, files) => {
      if (error) return send("ошибка загрузки файла", undefined, 400);
      const file = (files.file || [])[0];
      if (!file) return send("файл не передан", undefined, 400);
      const name = path.basename(file.originalFilename);
      fs.renameSync(file.path, path.join(staticDir, name));
      send(`сохранен файл: ${name}`);
    });
    return;
  }
  if (req.method === "GET" && url.pathname === "/09-08") {
    const file = path.join(staticDir, "MyFile.txt");
    res.writeHead(200, {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": "attachment; filename=MyFile.txt",
    });
    fs.createReadStream(file).pipe(res);
    return;
  }
  send("не найдено", undefined, 404);
});
server.listen(3000, () => console.log("сервер запущен: http://localhost:3000"));
