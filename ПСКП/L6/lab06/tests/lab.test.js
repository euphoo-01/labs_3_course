'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const path = require('node:path');
const fs = require('node:fs');
const { send } = require('../m0603');
const { createServer } = require('../server');

async function withServer(overrides, run) {
  const server = createServer(overrides);
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  try {
    return await run(`http://127.0.0.1:${server.address().port}`);
  } finally {
    await new Promise((resolve, reject) => server.close(err => err ? reject(err) : resolve()));
  }
}

function postForm(base, task, data) {
  return fetch(`${base}/${task}/send`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(data).toString()
  });
}

const mockSenders = () => ({
  send02: async () => ({ dryRun: true }),
  send03: async () => ({ dryRun: true }),
  send04: async () => ({ dryRun: true })
});

test('m0603 экспортирует только send(message)', () => {
  assert.deepEqual(Object.keys(require('../m0603')), ['send']);
  assert.equal(typeof send, 'function');
  assert.equal(send.length, 1);
});

test('m0603: фиксированный адрес получателя и проверка строки', async () => {
  const original = process.env.MAIL_DRY_RUN;
  process.env.MAIL_DRY_RUN = '1';
  try {
    const reply = await send('Строка из теста');
    assert.equal(reply.dryRun, true);
    assert.equal(reply.to, 'student@example.test');
    assert.equal(reply.text, 'Строка из теста');
    await assert.rejects(send(25), /строка/i);
    await assert.rejects(send('   '), /от 1 до 5000/);
  } finally {
    if (original === undefined) delete process.env.MAIL_DRY_RUN;
    else process.env.MAIL_DRY_RUN = original;
  }
});

test('один сервер: меню и все три GET маршрута', async () => {
  await withServer(mockSenders(), async base => {
    const home = await fetch(base);
    assert.equal(home.status, 200);
    const index = await home.text();
    for (const route of ['/06-02', '/06-03', '/06-04']) {
      assert.match(index, new RegExp(`href="${route}"`));
      const page = await fetch(base + route);
      assert.equal(page.status, 200);
      assert.match(await page.text(), new RegExp(`action="${route}/send"`));
    }
  });
});

test('06-02: POST отправляет объект через sendmail, проверяет поля и методы', async () => {
  const calls = [];
  await withServer({ ...mockSenders(), send02: async letter => {
    calls.push(letter);
    return { dryRun: true };
  } }, async base => {
    const valid = await postForm(base, '06-02', {
      from: 'sender@example.test', to: 'receiver@example.test', message: 'Привет'
    });
    assert.equal(valid.status, 200);
    assert.match(await valid.text(), /НЕ отправлено/);
    assert.deepEqual(calls[0], {
      from: 'sender@example.test', to: 'receiver@example.test',
      subject: 'ПСКП — ЛР 06-02', text: 'Привет'
    });

    const invalid = await postForm(base, '06-02', {
      from: 'bad\nemail@some.net', to: 'receiver@example.test', message: 'ОК'
    });
    assert.equal(invalid.status, 400);
    assert.equal(calls.length, 1);

    const xss = await postForm(base, '06-02', {
      from: 'sender@example.test', to: 'receiver@example.test', message: '<script>alert(1)</script>'
    });
    assert.equal(xss.status, 200);
    assert.doesNotMatch(await xss.text(), /<script>alert\(1\)<\/script>/);
  });
});

test('06-03 и 06-04: независимые POST маршруты вызывают нужный модуль', async () => {
  const localCalls = [];
  const installedCalls = [];
  await withServer({ ...mockSenders(),
    send03: async msg => { localCalls.push(msg); return { dryRun: true }; },
    send04: async msg => { installedCalls.push(msg); return { dryRun: true }; }
  }, async base => {
    assert.equal((await postForm(base, '06-03', { message: 'локальный модуль' })).status, 200);
    assert.equal((await postForm(base, '06-04', { message: 'npm пакет' })).status, 200);
    assert.deepEqual(localCalls, ['локальный модуль']);
    assert.deepEqual(installedCalls, ['npm пакет']);
    assert.equal((await postForm(base, '06-03', { message: ' ' })).status, 400);
    assert.equal((await postForm(base, '06-04', { message: ' ' })).status, 400);
  });
});

test('06-04: пакет загружается из контекста отдельного npm-потребителя', () => {
  const consumerRequire = createRequire(path.join(__dirname, '..', '06-04', 'package.json'));
  const packagePath = path.join(__dirname, '..', '06-04', 'node_modules', 'm0603', 'package.json');
  if (fs.existsSync(packagePath)) {
    // npm install file:../m0603 может создать символьную ссылку на исходники,
    // поэтому require.resolve возвращает физический путь, а не путь node_modules.
    assert.equal(typeof consumerRequire('m0603').send, 'function');
    assert.ok(consumerRequire.resolve.paths('m0603').some(p => p.endsWith(path.join('06-04', 'node_modules'))));
  } else {
    assert.throws(() => consumerRequire.resolve('m0603'), { code: 'MODULE_NOT_FOUND' });
  }
});

test('HTTP ошибки: неизвестный маршрут, неверный Content-Type и слишком большой POST', async () => {
  await withServer(mockSenders(), async base => {
    assert.equal((await fetch(`${base}/missing`)).status, 404);
    assert.equal((await fetch(`${base}/send`)).status, 404);
    assert.equal((await fetch(`${base}/06-02/send`)).status, 404);
    const unsupported = await fetch(`${base}/06-02/send`, {
      method: 'POST', headers: { 'content-type': 'text/plain' }, body: 'hello'
    });
    assert.equal(unsupported.status, 415);
    const longMessage = await postForm(base, '06-02', {
      from: 'sender@example.test', to: 'receiver@example.test', message: 'x'.repeat(17000)
    });
    assert.equal(longMessage.status, 413);
  });
});

test('интеграция: один сервер вызывает настоящие обработчики в MAIL_DRY_RUN', async () => {
  const old = process.env.MAIL_DRY_RUN;
  process.env.MAIL_DRY_RUN = '1';
  try {
    await withServer({}, async base => {
      const step02 = await postForm(base, '06-02', {
        from: 'sender@example.test', to: 'receiver@example.test', message: 'проверка 02'
      });
      assert.equal(step02.status, 200);
      assert.equal((await postForm(base, '06-03', { message: 'проверка 03' })).status, 200);
      const step04 = await postForm(base, '06-04', { message: 'проверка 04' });
      const packagePath = path.join(__dirname, '..', '06-04', 'node_modules', 'm0603', 'package.json');
      assert.equal(step04.status, fs.existsSync(packagePath) ? 200 : 503);
    });
  } finally {
    if (old === undefined) delete process.env.MAIL_DRY_RUN;
    else process.env.MAIL_DRY_RUN = old;
  }
});
