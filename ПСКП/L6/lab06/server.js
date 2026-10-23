"use strict";

const http = require("node:http");
const path = require("node:path");
const fs = require("node:fs");
const { createRequire } = require("node:module");
const {
  HttpError,
  isEmail,
  readForm,
  sendHtml,
  pageWithNotice,
  template,
  listen,
} = require("./lib/http");
const { sendEmail } = require("./lib/mail");
const { send: localSend } = require("./m0603");

const requireFrom0604 = createRequire(
  path.join(__dirname, "06-04", "package.json"),
);

function installedSend(message) {
  try {
    requireFrom0604.resolve("m0603");
  } catch (error) {
    if (error.code === "MODULE_NOT_FOUND") {
      throw new HttpError(
        503,
        "Модуль m0603 не установлен для 06-04. Выполните: cd 06-04 && npm install",
      );
    }
    throw error;
  }
  const { send } = requireFrom0604("m0603");
  return send(message);
}

function validate02(params) {
  const from = (params.get("from") || "").trim();
  const to = (params.get("to") || "").trim();
  const message = (params.get("message") || "").trim();
  if (!isEmail(from))
    throw new HttpError(400, "Введите корректный email отправителя.");
  if (!isEmail(to))
    throw new HttpError(400, "Введите корректный email получателя.");
  if (!message || message.length > 5000) {
    throw new HttpError(
      400,
      "Сообщение должно содержать от 1 до 5000 символов.",
    );
  }
  return { from, to, subject: "ПСКП — ЛР 06-02", text: message };
}

function validateMessage(params) {
  const message = (params.get("message") || "").trim();
  if (!message || message.length > 5000) {
    throw new HttpError(400, "Введите сообщение от 1 до 5000 символов.");
  }
  return message;
}

function createServer({
  send02 = sendEmail,
  send03 = localSend,
  send04 = installedSend,
} = {}) {
  const home = template("index.html");
  const routes = new Map([
    [
      "/06-02",
      { page: template("06-02.html"), validate: validate02, send: send02 },
    ],
    [
      "/06-03",
      { page: template("06-03.html"), validate: validateMessage, send: send03 },
    ],
    [
      "/06-04",
      { page: template("06-04.html"), validate: validateMessage, send: send04 },
    ],
  ]);

  return http.createServer(async (req, res) => {
    const pathname = new URL(req.url || "/", "http://localhost").pathname;

    if (req.method === "GET" && pathname === "/") {
      sendHtml(res, home);
      return;
    }

    if (req.method === "GET" && pathname === "/styles.css") {
      res.writeHead(200, {
        "Content-Type": "text/css; charset=utf-8",
      });

      fs.createReadStream(path.join(__dirname, "public", "styles.css")).pipe(
        res,
      );

      return;
    }

    const selectedPage = routes.get(pathname);
    if (req.method === "GET" && selectedPage) {
      sendHtml(res, selectedPage.page);
      return;
    }

    const postPage = pathname.endsWith("/send")
      ? routes.get(pathname.slice(0, -5))
      : undefined;
    if (req.method === "POST" && postPage) {
      try {
        const params = await readForm(req);
        const payload = postPage.validate(params);
        const result = await postPage.send(payload);
        const info = result?.dryRun
          ? "Тестовый режим: письмо сформировано, но НЕ отправлено. Смотрите терминал."
          : "SMTP-сервер принял письмо для отправки. Доставка не гарантирована.";
        sendHtml(res, pageWithNotice(postPage.page, info));
      } catch (error) {
        if (
          error instanceof HttpError ||
          error instanceof TypeError ||
          error instanceof RangeError
        ) {
          sendHtml(
            res,
            pageWithNotice(postPage.page, error.message, "error"),
            error.status || 400,
          );
        } else {
          console.error("Ошибка отправки письма:", error);
          sendHtml(
            res,
            pageWithNotice(
              postPage.page,
              "Не удалось отправить письмо. Проверьте настройки SMTP и вывод терминала.",
              "error",
            ),
            502,
          );
        }
      }
      return;
    }

    sendHtml(
      res,
      pageWithNotice(
        home,
        "Неизвестный маршрут. Выберите задание из меню.",
        "error",
      ),
      404,
    );
  });
}

if (require.main === module) listen(createServer(), 3000);
module.exports = { createServer, validate02, validateMessage, installedSend };
