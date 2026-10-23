'use strict';

const FIXED_RECIPIENT = 'student@example.test';
const FROM_ADDRESS = 'sender@example.test';

/**
 * @param {string} message — текст письма (единственный параметр)
 * @returns {Promise<object>} — разрешается после ответа SMTP; ошибка => reject
 */
async function send(message) {
  if (typeof message !== 'string') {
    throw new TypeError('send(message): ожидается строка.');
  }
  if (!message.trim() || message.length > 5000) {
    throw new RangeError('Строка должна содержать от 1 до 5000 символов.');
  }

  const letter = {
    from: FROM_ADDRESS,
    to: FIXED_RECIPIENT,
    subject: 'ПСКП — сообщение из m0603',
    text: message,
    html: `<div style="white-space:pre-wrap">${escapeHtml(message)}</div>`
  };

  if (process.env.MAIL_DRY_RUN === '1') {
    console.log('[DRY RUN] m0603 — письмо НЕ отправлено:', JSON.stringify(letter, null, 2));
    return { dryRun: true, from: letter.from, to: letter.to, text: letter.text };
  }

  const options = { silent: true };
  if (process.env.MAIL_DEV_PORT) {
    const port = Number(process.env.MAIL_DEV_PORT);
    if (!Number.isInteger(port) || port < 1 || port > 65535) {
      throw new Error('MAIL_DEV_PORT должен быть от 1 до 65535.');
    }
    options.devPort = port;
    options.devHost = process.env.MAIL_DEV_HOST || '127.0.0.1';
  }

  const sendmail = require('sendmail')(options);
  return new Promise((resolve, reject) => {
    sendmail(letter, (error, reply) => {
      if (error) reject(error);
      else resolve(reply || {});
    });
  });
}

function escapeHtml(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
}

module.exports = { send };
