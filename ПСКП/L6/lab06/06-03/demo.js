'use strict';

// Пример из методички: приложение вызывает отправку одной строки.
const { send } = require('../m0603');

send('Тестовое сообщение из приложения 06-03')
  .then(() => console.log('Вызов send() успешно завершён.'))
  .catch((error) => {
    console.error('Ошибка отправки:', error.message);
    process.exitCode = 1;
  });
