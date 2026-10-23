'use strict';

// Кроссплатформенный старт без установки дополнительных утилит.
const { spawnSync } = require('node:child_process');
const path = require('node:path');
const target = process.argv[2];
if (!target) {
  console.error('Использование: node scripts/dry-run.js <server.js>');
  process.exit(2);
}
const result = spawnSync(process.execPath, [path.resolve(target)], {
  env: { ...process.env, MAIL_DRY_RUN: '1' },
  stdio: 'inherit'
});
if (result.error) {
  console.error(result.error.message);
  process.exit(1);
}
process.exit(result.status === null ? 1 : result.status);
