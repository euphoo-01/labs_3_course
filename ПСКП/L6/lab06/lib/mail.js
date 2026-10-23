'use strict';

/**
 * Используем именно npm-пакет sendmail, как требует лабораторная работа.
 * MAIL_DRY_RUN=1 — только проверка логики, без фактической отправки.
 * MAIL_DEV_PORT=1025 — отправка на локальный SMTP-приёмник для демонстрации.
 */
function mailClient() {
  const options = { silent: true };
  if (process.env.MAIL_DEV_PORT) {
    const port = Number(process.env.MAIL_DEV_PORT);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('MAIL_DEV_PORT должен быть от 1 до 65535.');
    }
    options.devPort = port;
    options.devHost = process.env.MAIL_DEV_HOST || '127.0.0.1';
  }
  return require('sendmail')(options);
}

function sendEmail({ from, to, subject, text }) {
  if (process.env.MAIL_DRY_RUN === '1') {
    console.log('[DRY RUN] Письмо (НЕ отправлено):', JSON.stringify({ from, to, subject, text }, null, 2));
    return Promise.resolve({ dryRun: true });
  }

  const sendmail = mailClient();
  const html = `<div style="white-space:pre-wrap">${escapeForEmail(text)}</div>`;
  return new Promise((resolve, reject) => {
    sendmail({ from, to, subject, text, html }, (error, reply) => {
      if (error) reject(error);
      else resolve(reply || {});
    });
  });
}

function escapeForEmail(text) {
  return text.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

module.exports = { sendEmail };
