"use strict";

const fs = require("node:fs");
const path = require("node:path");

const MAX_BODY_BYTES = 16 * 1024;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function isEmail(value) {
  return (
    typeof value === "string" &&
    value.length <= 254 &&
    /^[^\s@<>,;\r\n]+@[^\s@<>,;\r\n]+\.[^\s@<>,;\r\n]+$/.test(value)
  );
}

function readForm(request) {
  return new Promise((resolve, reject) => {
    const type = request.headers["content-type"] || "";
    if (!type.toLowerCase().startsWith("application/x-www-form-urlencoded")) {
      reject(
        new HttpError(415, "Нужен тип application/x-www-form-urlencoded."),
      );
      request.resume();
      return;
    }

    let body = "";
    let bytes = 0;
    let tooLarge = false;
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      bytes += Buffer.byteLength(chunk, "utf8");
      if (bytes > MAX_BODY_BYTES) {
        tooLarge = true;
      } else if (!tooLarge) {
        body += chunk;
      }
    });
    request.on("end", () => {
      if (tooLarge) reject(new HttpError(413, "Слишком длинное сообщение."));
      else resolve(new URLSearchParams(body));
    });
    request.on("error", reject);
  });
}

function sendHtml(response, html, status = 200) {
  response.writeHead(status, {
    "content-type": "text/html; charset=utf-8",
    "cache-control": "no-store",
    "content-security-policy":
      "default-src 'none'; style-src 'self' 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  });
  response.end(html);
}

function template(filename) {
  return fs.readFileSync(
    path.join(__dirname, "..", "public", filename),
    "utf8",
  );
}

function pageWithNotice(page, message, type = "ok") {
  const klass = type === "error" ? "notice error" : "notice success";
  return page.replace(
    "<!-- FEEDBACK -->",
    `<div class="${klass}" role="status">${escapeHtml(message)}</div>`,
  );
}

function listen(server, defaultPort) {
  const port =
    process.env.PORT === undefined ? defaultPort : Number(process.env.PORT);
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error("PORT должен быть числом от 0 до 65535");
  }
  const host = process.env.HOST || "127.0.0.1";
  server.listen(port, host, () => {
    const actual = server.address().port;
    console.log(`Сервер доступен: http://${host}:${actual}`);
    if (process.env.MAIL_DRY_RUN === "1")
      console.log("MAIL_DRY_RUN=1: письма не отправляются.");
  });
}

module.exports = {
  HttpError,
  escapeHtml,
  isEmail,
  readForm,
  sendHtml,
  pageWithNotice,
  listen,
  template,
};
