# ASPA0011_1 — лабораторная 2

ASP.NET Core 8 Web API с `System.Threading.Channels` и встроенным Logging.

## Создание solution

Из каталога над проектом:

```bash
dotnet new sln -n ASPA
dotnet sln ASPA.sln add ASPA0011_1/ASPA0011_1.csproj
```

## Запуск

```bash
cd ASPA0011_1
dotnet restore
dotnet run
```

По `launchSettings.json` приложение слушает `http://localhost:5080` и запускается в Development.
`app.log` появляется в корне проекта.

## Что показать преподавателю

1. Создать ACTIVE канал.
2. Повторно выполнить `open` для него — `Warning` в терминале и `app.log`.
3. Выполнить первый `enqueue` — очередь заполнится (capacity=1).
4. Выполнить второй `enqueue` — через `WaitEnqueue=3` сек. будет `Warning` и HTTP 408.
5. Запросить несуществующий GUID — `Error` и HTTP 404.
6. Показать те же записи в `app.log`.
7. Показать Trace/Debug в `app.log` в Development.
8. Объяснить, что стандартные `Microsoft` Error/Critical идут только в Console, а не в файл.

## Форматы JSON по заданию

- JSON-1: `{ id, name, state, description }`
- JSON-2: `{ command:"new", name, state, description }`
- JSON-3/4: `close` всех или одного канала
- JSON-5/6: `open` всех или одного канала
- JSON-7/8: `del` всех или всех CLOSED
- JSON-9: `dequeue`/`peek` + id
- JSON-10: `enqueue` + id + data
- JSON-11: `{ id, data }`
