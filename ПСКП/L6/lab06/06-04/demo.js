'use strict';

const { send } = require('@euphoo/m0603');

send('Тест из приложения 06-04: установленный npm-пакет')
  .then(() => console.log('Вызов импортированного пакета завершён.'))
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
