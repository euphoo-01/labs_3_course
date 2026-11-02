# Лабораторная работа 07

Сервер Node.js отдаёт статические файлы по пути относительно настроенного каталога. Для разрешённых расширений устанавливается MIME-тип из задания. Необрабатываемый GET получает `404`, любой метод кроме GET — `405` с `Allow: GET`.

## Запуск

Требуются Node.js 18 или новее и npm. Сторонние зависимости отсутствуют; `npm install` не нужен.

```sh
cd L7/lab07
npm start
```

Откройте [http://localhost:3000/index.html](http://localhost:3000/index.html). Остановить сервер можно сочетанием Ctrl+C.

Порт можно изменить переменной `PORT`, а корневой каталог — переменной `STATIC_DIR`. По умолчанию используются `3000` и `static`. Относительный путь `STATIC_DIR` разрешается относительно каталога приложения `L7/lab07`, независимо от текущего рабочего каталога процесса:

```sh
PORT=3001 STATIC_DIR=static npm start
```

Модуль принимает параметры при подключении, а затем предоставляет фабрику обработчика:

```js
const { createStaticHandler } = require('./m07-01')({ path: 'static/' });
const handler = createStaticHandler();
```

## Проверка

При запущенном сервере в другом терминале выполните:

```sh
curl -i http://localhost:3000/index.html
curl -s -D - -o /dev/null http://localhost:3000/images/server.png
curl -i http://localhost:3000/missing.html
curl -i http://localhost:3000/unknown.txt
curl -i -X POST http://localhost:3000/index.html
```

Ожидаются успешные ответы на существующие HTML и вложенный PNG, затем `404` для отсутствующего файла и неподдерживаемого расширения, `405` для POST.

В браузере убедитесь, что стили и сценарий подключены, изображение отображается, видео воспроизводится, ссылка на DOCX работает, а содержимое JSON и XML загружено через `fetch` и показано на странице. На вкладке Network инструментов разработчика можно проверить запросы и заголовки `Content-Type`.

## Файлы

- `server.js` — создание и запуск HTTP-сервера.
- `m07-01.js` — параметризованный обработчик статических файлов.
- `static/index.html` — демонстрационная страница; `static/styles/main.css` и `static/scripts/main.js` — её стили и сценарий.
- `static/images/server.png`, `static/media/demo.mp4`, `static/documents/lab07.docx` — изображение, видео и документ.
- `static/data/example.json` и `static/data/example.xml` — данные для запросов `fetch`.
- `THEORY_RU.md` — ответы на теоретические вопросы и ссылки на источники.
