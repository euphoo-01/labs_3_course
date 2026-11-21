const http = require("http");
const fs = require("fs");
const path = require("path");
const querystring = require("querystring");
const { parseString } = require("xml2js");
const xmlbuilder = require("xmlbuilder");
const multiparty = require("multiparty");

const staticDir = path.join(__dirname, "static");
let responseId = 0;

function send(res, body, type = "text/plain", code = 200) {
  res.writeHead(code, { "Content-Type": `${type}; charset=utf-8` });
  res.end(body);
}

function readBody(req, callback) {
  let body = "";
  req.setEncoding("utf8");
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => callback(body));
}

function calculate(res, x, y, error) {
  if (
    x === null ||
    y === null ||
    x.trim() === "" ||
    y.trim() === "" ||
    !Number.isFinite(Number(x)) ||
    !Number.isFinite(Number(y))
  ) {
    return send(res, error);
  }
  x = Number(x);
  y = Number(y);
  send(
    res,
    `сумма: ${x + y}\nразность: ${x - y}\nпроизведение: ${x * y}\nчастное: ${x / y}`,
  );
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://localhost");
  const pathname = url.pathname;

  if (req.method === "GET") {
    if (pathname === "/connection" || pathname.startsWith("/connection/set=")) {
      const value = url.searchParams.get("set") ?? pathname.split("set=")[1];
      if (value !== undefined && value !== null) {
        const timeout = Number(value);
        if (!Number.isFinite(timeout) || timeout < 0)
          return send(res, "ошибка значения set", "text/plain", 400);
        server.keepAliveTimeout = timeout;
        return send(
          res,
          `установлено новое значение параметра KeepAliveTimeout=${timeout}`,
        );
      }
      return send(res, `KeepAliveTimeout=${server.keepAliveTimeout}`);
    }
    if (pathname === "/headers") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("X-Lab", "08");
      res.writeHead(200);
      return res.end(
        `заголовки запроса:\n${JSON.stringify(req.headers, null, 2)}\n\nзаголовки ответа:\n${res._header}`,
      );
    }
    if (pathname === "/parameter") {
      return calculate(
        res,
        url.searchParams.get("x"),
        url.searchParams.get("y"),
        "ошибка: x и y должны быть числами",
      );
    }
    if (pathname.startsWith("/parameter/")) {
      const parts = pathname.split("/");
      if (parts.length !== 4) return send(res, req.url);
      return calculate(
        res,
        decodeURIComponent(parts[2]),
        decodeURIComponent(parts[3]),
        req.url,
      );
    }
    if (pathname === "/close") {
      send(res, "сервер будет закрыт через 10 секунд");
      setTimeout(() => {
        server.close(() => console.log("сервер закрыт"));
        server.closeAllConnections();
      }, 10000);
      return;
    }
    if (pathname === "/socket") {
      return send(
        res,
        `клиент: ${req.socket.remoteAddress}:${req.socket.remotePort}\nсервер: ${req.socket.localAddress}:${req.socket.localPort}`,
      );
    }
    if (pathname === "/resp-status") {
      const code = Number(url.searchParams.get("code"));
      const message = url.searchParams.get("mess");
      if (
        !Number.isInteger(code) ||
        code < 200 ||
        code > 599 ||
        !message ||
        /[^\x20-\x7e]/.test(message)
      ) {
        return send(
          res,
          "ошибка: задайте code от 200 до 599 и mess латиницей",
          "text/plain",
          400,
        );
      }
      res.writeHead(code, message, {
        "Content-Type": "text/plain; charset=utf-8",
      });
      return res.end(`${code} ${message}`);
    }
    if (pathname === "/" || pathname === "/formparameter") {
      return send(
        res,
        fs.readFileSync(path.join(__dirname, "form.html")),
        "text/html",
      );
    }
    if (pathname === "/files") {
      fs.readdir(staticDir, { withFileTypes: true }, (err, files) => {
        if (err)
          return send(res, "ошибка чтения директории", "text/plain", 500);
        const names = files
          .filter((file) => file.isFile())
          .map((file) => file.name);
        res.setHeader("X-static-files-count", names.length);
        send(res, names.join("\n"));
      });
      return;
    }
    if (pathname.startsWith("/files/")) {
      const filename = decodeURIComponent(pathname.slice("/files/".length));
      if (filename !== path.basename(filename))
        return send(res, "файл не найден", "text/plain", 404);
      fs.readFile(path.join(staticDir, filename), (err, data) => {
        if (err) return send(res, "файл не найден", "text/plain", 404);
        const types = {
          ".txt": "text/plain",
          ".html": "text/html",
          ".json": "application/json",
          ".xml": "application/xml",
          ".png": "image/png",
          ".jpg": "image/jpeg",
          ".pdf": "application/pdf",
        };
        res.writeHead(200, {
          "Content-Type":
            types[path.extname(filename)] || "application/octet-stream",
        });
        res.end(data);
      });
      return;
    }
    if (pathname === "/upload") {
      return send(
        res,
        fs.readFileSync(path.join(__dirname, "upload.html")),
        "text/html",
      );
    }
  }

  if (
    pathname === "/req-data" &&
    (req.method === "GET" || req.method === "POST")
  ) {
    let total = 0;
    let count = 0;
    req.on("data", (chunk) => {
      total += chunk.length;
      console.log(`порция ${++count}: ${chunk.length} байт`);
    });
    req.on("end", () =>
      send(res, `получено порций: ${count}\nвсего байт: ${total}`),
    );
    return;
  }

  if (req.method === "POST") {
    if (pathname === "/formparameter") {
      return readBody(req, (body) =>
        send(res, JSON.stringify(querystring.parse(body), null, 2)),
      );
    }
    if (pathname === "/json") {
      return readBody(req, (body) => {
        try {
          const data = JSON.parse(body);
          send(
            res,
            JSON.stringify({
              __comment: "ответ. лабораторная работа 8/10",
              x_plus_y: data.x + data.y,
              Concatination_s_o: `${data.s}: ${Object.values(data.o).join(", ")}`,
              Length_m: data.m.length,
            }),
            "application/json",
          );
        } catch {
          send(
            res,
            JSON.stringify({ error: "ошибка json" }),
            "application/json",
            400,
          );
        }
      });
    }
    if (pathname === "/xml") {
      return readBody(req, (body) =>
        parseString(body, (err, data) => {
          if (err || !data.request)
            return send(
              res,
              "<error>ошибка xml</error>",
              "application/xml",
              400,
            );
          const request = data.request;
          const sum = (request.x || []).reduce(
            (result, x) => result + Number(x.$.value),
            0,
          );
          const concat = (request.m || []).map((m) => m.$.value).join("");
          const xml = xmlbuilder
            .create("response")
            .att("id", ++responseId)
            .att("request", request.$.id);
          xml.ele("sum", { element: "x", result: sum });
          xml.ele("concat", { element: "m", result: concat });
          send(res, xml.end({ pretty: true }), "application/xml");
        }),
      );
    }
    if (pathname === "/upload") {
      const form = new multiparty.Form({ uploadDir: staticDir });
      form.parse(req, (err, fields, files) => {
        if (err) return send(res, "ошибка загрузки файла", "text/plain", 400);
        const uploaded = files.file || [];
        const names = uploaded.map((file) => {
          const name = path.basename(file.originalFilename);
          fs.renameSync(file.path, path.join(staticDir, name));
          return name;
        });
        send(res, `сохранены файлы: ${names.join(", ")}`);
      });
      return;
    }
  }

  send(res, "не найдено", "text/plain", 404);
});

server.on("connection", (socket) => {
  console.log(
    `соединение: ${socket.remoteAddress}:${socket.remotePort}, KeepAliveTimeout=${server.keepAliveTimeout}`,
  );
  socket.on("close", () => console.log("соединение закрыто"));
});
server.listen(3000, () => console.log("сервер запущен: http://localhost:3000"));
