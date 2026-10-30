-- ============================================================================
-- ЛАБОРАТОРНАЯ РАБОТА № 5. Oracle Database
-- Тема: архитектура сервера, SGA, буферный кэш, процессы, Listener.
-- Среда: Oracle в Docker на Arch Linux; SQL Developer / SQL*Plus.
--
-- ЗАПУСК В SQL DEVELOPER: открыть файл -> выбрать подключение -> F5 (Run Script).
-- Для отдельных запросов можно использовать Ctrl+Enter (Run Statement).
--
-- ПРАВА:
--   - SELECT на V$-представления (или соответствующие каталожные права);
--   - CREATE TABLE и квота на табличное пространство для заданий 7 и 8;
--   - НЕ выполнять CREATE TABLE в схеме SYS / корне CDB.
--
-- ПОДКЛЮЧЕНИЕ:
--   - диагностические представления относятся к инстансу/CDB;
--   - свои LAB05_* таблицы создавать в пользовательской схеме PDB.
--
-- Скрипт не изменяет параметры инстанса и Listener.
-- При повторном запуске удаляет и заново создаёт ТОЛЬКО LAB05_KEEP и
-- LAB05_DEFAULT в ТЕКУЩЕЙ СХЕМЕ. Остальные объекты не затрагиваются.
--
-- Если KEEP = 0, задание 7 будет пропущено с объяснением.
-- Администратор CDB может включить KEEP ОТДЕЛЬНО (пример):
--   -- Подключитесь с админскими правами к CDB$ROOT:
--   -- ALTER SYSTEM SET DB_KEEP_CACHE_SIZE = 64M SCOPE=MEMORY;
-- Размер зависит от конфигурации и доступной SGA; команда не гарантирует успех.
-- После изменения параметра повторно запустите весь файл в пользовательской PDB.
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET VERIFY OFF

PROMPT
PROMPT ===== СВЕДЕНИЯ О ТЕКУЩЕМ ПОДКЛЮЧЕНИИ =====
SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS CURRENT_SCHEMA,
       SYS_CONTEXT('USERENV', 'CON_NAME')      AS CONTAINER_NAME,
       SYS_CONTEXT('USERENV', 'SERVICE_NAME')  AS SERVICE_NAME
FROM DUAL;

PROMPT
PROMPT ===== 1. ОБЩИЙ РАЗМЕР SGA =====
-- V$SGA содержит составные части SGA; сумма VALUE даёт выделенный объём.
SELECT ROUND(SUM(value) / 1024 / 1024, 2) AS SGA_TOTAL_MB
FROM v$sga;

PROMPT
PROMPT ===== 2. ТЕКУЩИЕ РАЗМЕРЫ ОСНОВНЫХ КОМПОНЕНТОВ SGA =====
-- CURRENT_SIZE - фактический объём, а не желаемый размер из параметров.
-- Показываем также отключённые компоненты (0 МБ).
SELECT component,
       ROUND(current_size / 1024 / 1024, 2) AS current_mb,
       ROUND(min_size / 1024 / 1024, 2)     AS min_mb,
       ROUND(max_size / 1024 / 1024, 2)     AS max_mb,
       last_oper_type
FROM v$sga_dynamic_components
ORDER BY component;

PROMPT
PROMPT ===== 3. РАЗМЕР ГРАНУЛЫ ДЛЯ КАЖДОГО КОМПОНЕНТА =====
-- Гранула - минимальная единица распределения динамических компонентов SGA.
-- У фиксированной SGA и буфера redo свои особенности (не делятся на гранулы).
SELECT component,
       ROUND(granule_size / 1024 / 1024, 2) AS granule_mb,
       ROUND(current_size / 1024 / 1024, 2) AS component_mb
FROM v$sga_dynamic_components
ORDER BY component;

-- Общий размер гранулы, определённый для инстанса:
SELECT name, ROUND(bytes / 1024 / 1024, 2) AS granule_mb
FROM v$sgainfo
WHERE name = 'Granule Size';

PROMPT
PROMPT ===== 4. ДОСТУПНАЯ СВОБОДНАЯ ПАМЯТЬ В SGA =====
-- Это свободная память, доступная для изменения размеров компонентов SGA.
-- Не путать с free memory ВНУТРИ shared pool / large pool.
SELECT name,
       ROUND(bytes / 1024 / 1024, 2) AS free_sga_mb
FROM v$sgainfo
WHERE name = 'Free SGA Memory Available';

-- Отдельно выводим свободную память в конкретных пулах.
SELECT NVL(pool, '(без имени пула)') AS pool,
       ROUND(SUM(bytes) / 1024 / 1024, 2) AS free_inside_pool_mb
FROM v$sgastat
WHERE name = 'free memory'
GROUP BY pool
ORDER BY pool;

PROMPT
PROMPT ===== 5. МАКСИМАЛЬНЫЙ И ЦЕЛЕВОЙ РАЗМЕР SGA =====
-- SGA_MAX_SIZE - верхняя граница; SGA_TARGET - цель автоматической настройки.
-- MEMORY_TARGET/MAX_TARGET (и MEMORY_SIZE в новых версиях) - другие режимы.
SELECT name, display_value AS parameter_value,
       ROUND(TO_NUMBER(value) / 1024 / 1024, 2) AS value_mb
FROM v$parameter
WHERE name IN ('sga_max_size', 'sga_target', 'memory_target',
               'memory_max_target', 'memory_size')
ORDER BY name;

PROMPT
PROMPT ===== 6. РАЗМЕРЫ KEEP, DEFAULT И RECYCLE =====
-- V$BUFFER_POOL.CURRENT_SIZE уже выражен В МЕГАБАЙТАХ (не в байтах).
-- LEFT JOIN позволяет увидеть нулевые/не созданные пулы.
-- Для DEFAULT могут быть под-кэши с разными размерами блока.
WITH pool_names AS (
    SELECT 'DEFAULT' AS pool_name FROM dual UNION ALL
    SELECT 'KEEP' FROM dual UNION ALL
    SELECT 'RECYCLE' FROM dual
)
SELECT n.pool_name,
       NVL(SUM(p.current_size), 0) AS current_mb,
       NVL(SUM(p.buffers), 0)      AS buffer_count
FROM pool_names n
LEFT JOIN v$buffer_pool p ON p.name = n.pool_name
GROUP BY n.pool_name
ORDER BY CASE n.pool_name
           WHEN 'KEEP' THEN 1 WHEN 'DEFAULT' THEN 2 ELSE 3 END;

-- Настройки: 0 обычно означает, что отдельный пул не выделен.
SELECT name, display_value, ispdb_modifiable
FROM v$parameter
WHERE name IN ('db_cache_size', 'db_keep_cache_size',
               'db_recycle_cache_size', 'db_block_size')
ORDER BY name;

PROMPT
PROMPT ===== 7. ТАБЛИЦА С СЕГМЕНТОМ В KEEP =====
-- STORAGE (BUFFER_POOL KEEP) задаёт пул для блоков СЕГМЕНТА таблицы.
-- SEGMENT CREATION IMMEDIATE гарантирует наличие сегмента в USER_SEGMENTS.
-- ВАЖНО: KEEP не закрепляет блоки навечно, а использует собственный пул.
-- Если DB_KEEP_CACHE_SIZE = 0, пропускаем создание, не выдавая ложный результат.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE LAB05_KEEP PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

DECLARE
    v_keep_size NUMBER;
BEGIN
    SELECT TO_NUMBER(value)
      INTO v_keep_size
      FROM v$parameter
     WHERE name = 'db_keep_cache_size';

    IF v_keep_size = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Задание 7: KEEP отключён (DB_KEEP_CACHE_SIZE=0).');
        DBMS_OUTPUT.PUT_LINE('Нужно включить KEEP в CDB$ROOT от DBA, затем перезапустить скрипт.');
    ELSE
        EXECUTE IMMEDIATE '
            CREATE TABLE LAB05_KEEP (
                id NUMBER NOT NULL,
                note VARCHAR2(100)
            )
            SEGMENT CREATION IMMEDIATE
            STORAGE (BUFFER_POOL KEEP)';
        EXECUTE IMMEDIATE '
            INSERT INTO LAB05_KEEP (id, note)
            SELECT level, ''KEEP data '' || TO_CHAR(level)
            FROM dual CONNECT BY level <= 100';
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Задание 7: LAB05_KEEP создана с BUFFER_POOL KEEP.');
    END IF;
END;
/

-- Доказательство: пул сегмента, выделенные блоки и extents.
SELECT segment_name, segment_type, tablespace_name, buffer_pool,
       blocks, extents, ROUND(bytes / 1024, 2) AS allocated_kb
FROM user_segments
WHERE segment_name = 'LAB05_KEEP';

PROMPT
PROMPT ===== 8. ТАБЛИЦА С СЕГМЕНТОМ В DEFAULT =====
-- CACHE меняет предпочтения кэширования при full table scan, но НЕ закрепляет
-- блоки в памяти и НЕ является аналогом BUFFER_POOL KEEP.
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE LAB05_DEFAULT PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN RAISE; END IF;
END;
/

CREATE TABLE LAB05_DEFAULT (
    id NUMBER NOT NULL,
    note VARCHAR2(100)
)
SEGMENT CREATION IMMEDIATE
STORAGE (BUFFER_POOL DEFAULT);

ALTER TABLE LAB05_DEFAULT CACHE;

INSERT INTO LAB05_DEFAULT (id, note)
SELECT level, 'DEFAULT data ' || TO_CHAR(level)
FROM dual
CONNECT BY level <= 100;
COMMIT;

-- Доказательство назначения пула на уровне сегмента.
SELECT segment_name, segment_type, tablespace_name, buffer_pool,
       blocks, extents, ROUND(bytes / 1024, 2) AS allocated_kb
FROM user_segments
WHERE segment_name = 'LAB05_DEFAULT';

-- CACHE - логический атрибут таблицы; не доказывает физическое присутствие
-- её блоков в SGA в момент выполнения запроса.
SELECT table_name, cache, segment_created
FROM user_tables
WHERE table_name = 'LAB05_DEFAULT';

-- Читаем данные, чтобы при подходящем плане Oracle мог загрузить блоки в кэш.
SELECT COUNT(*) AS default_row_count FROM LAB05_DEFAULT;

PROMPT
PROMPT ===== 9. РАЗМЕР БУФЕРА ЖУРНАЛА ПОВТОРА (REDO LOG BUFFER) =====
-- Не путать redo log buffer в SGA с размером файлов online redo log на диске.
SELECT name, ROUND(bytes / 1024 / 1024, 2) AS redo_buffer_mb
FROM v$sgainfo
WHERE name = 'Redo Buffers';

SELECT name, display_value AS log_buffer_parameter
FROM v$parameter
WHERE name = 'log_buffer';

PROMPT
PROMPT ===== 10. СВОБОДНАЯ ПАМЯТЬ В LARGE POOL =====
-- NULL/0 при отсутствии строк в V$SGASTAT может означать, что пул не выделен.
SELECT NVL(ROUND(SUM(CASE WHEN name = 'free memory' THEN bytes ELSE 0 END)
                 / 1024 / 1024, 2), 0) AS large_pool_free_mb,
       NVL(ROUND(SUM(bytes) / 1024 / 1024, 2), 0) AS large_pool_tracked_mb
FROM v$sgastat
WHERE pool = 'large pool';

SELECT name, display_value
FROM v$parameter
WHERE name = 'large_pool_size';

PROMPT
PROMPT ===== 11. РЕЖИМЫ ТЕКУЩИХ ПОЛЬЗОВАТЕЛЬСКИХ СОЕДИНЕНИЙ =====
-- SERVER: DEDICATED / SHARED / POOLED / PSEUDO / NONE.
-- SQL Developer обычно подключается как DEDICATED, если не настроен shared.
SELECT server AS connection_mode, COUNT(*) AS session_count
FROM v$session
WHERE type = 'USER' AND username IS NOT NULL
GROUP BY server
ORDER BY server;

-- Подробный список для демонстрации преподавателю.
SELECT sid, serial#, username, status, server,
       machine, program, service_name
FROM v$session
WHERE type = 'USER' AND username IS NOT NULL
ORDER BY username, sid;

PROMPT
PROMPT ===== 12. ДЕЙСТВИТЕЛЬНО РАБОТАЮЩИЕ ФОНОВЫЕ ПРОЦЕССЫ =====
-- Соединение по PADDR с V$PROCESS отсекает потенциальные/не запущенные BG.
SELECT b.name AS bg_name, b.description,
       p.pid AS oracle_pid, p.spid AS linux_pid, p.program
FROM v$bgprocess b
JOIN v$process p ON p.addr = b.paddr
WHERE b.name IS NOT NULL
ORDER BY b.name, p.pid;

PROMPT
PROMPT ===== 13. СЕРВЕРНЫЕ ПРОЦЕССЫ ТЕКУЩИХ СЕССИЙ =====
-- V$PROCESS.SPID - PID ОС ВНУТРИ контейнера, не обязательно PID на хосте.
-- Для shared server один процесс может обслуживать несколько сессий.
SELECT p.pid AS oracle_pid, p.spid AS container_pid, p.program,
       s.sid, s.serial#, s.username, s.server AS server_mode,
       s.status AS session_status
FROM v$process p
JOIN v$session s ON s.paddr = p.addr
WHERE s.type = 'USER' AND s.username IS NOT NULL
ORDER BY p.pid, s.sid;

-- В режиме Shared Server серверные процессы могут простаивать и временно
-- не быть привязаны к пользовательской сессии. Их смотрят отдельно:
SELECT ss.name AS shared_server_name, ss.status,
       p.spid AS container_pid, ss.requests
FROM v$shared_server ss
LEFT JOIN v$process p ON p.addr = ss.paddr
ORDER BY ss.name;

PROMPT
PROMPT ===== 14. ЧИСЛО ДЕЙСТВУЮЩИХ DBWn ПРОЦЕССОВ =====
-- DBW0, DBW1, ...; считаем фактически работающие процессы, не параметр.
SELECT COUNT(*) AS active_dbwn_count
FROM v$bgprocess b
JOIN v$process p ON p.addr = b.paddr
WHERE REGEXP_LIKE(b.name, '^DBW[0-9A-Z]$');

SELECT b.name, p.spid AS container_pid, b.description
FROM v$bgprocess b
JOIN v$process p ON p.addr = b.paddr
WHERE REGEXP_LIKE(b.name, '^DBW[0-9A-Z]$')
ORDER BY b.name;

SELECT name, display_value
FROM v$parameter
WHERE name = 'db_writer_processes';

PROMPT
PROMPT ===== 15. СЕРВИСЫ (ТОЧКИ ПОДКЛЮЧЕНИЯ К БД) =====
-- Сервисы в словаре БД не обязательно 1:1 равны списку в lsnrctl services:
-- Listener показывает те сервисы, которые в нём зарегистрированы.
SELECT name, network_name, con_id
FROM v$services
ORDER BY name;

-- Активные сервисы инстанса; список может отличаться от V$SERVICES:
SELECT name, network_name, con_name
FROM v$active_services
ORDER BY name;

SELECT SYS_CONTEXT('USERENV', 'SERVICE_NAME') AS current_service,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS current_container
FROM dual;

PROMPT
PROMPT ===== 16. НАСТРОЙКИ ДИСПЕТЧЕРОВ И SHARED SERVER =====
-- Если SHARED_SERVERS=0 и V$DISPATCHER пуст, Shared Server не запущен.
SELECT name, display_value, isdefault
FROM v$parameter
WHERE name IN ('dispatchers', 'shared_servers', 'max_shared_servers',
               'shared_server_sessions', 'circuits',
               'local_listener', 'remote_listener')
ORDER BY name;

SELECT name, status, network, messages
FROM v$dispatcher
ORDER BY name;

PROMPT
PROMPT ===== 17-20. LISTENER: КОМАНДЫ ИСПОЛНЯЮТСЯ В ТЕРМИНАЛЕ ARCH =====
PROMPT 17. docker ps ; docker exec ИМЯ_КОНТЕЙНЕРА sh -c "ps -ef"
PROMPT     Найдите процесс tnslsnr. Это Linux-процесс в контейнере, не Windows-сервис.
PROMPT 18. docker exec ИМЯ_КОНТЕЙНЕРА sh
PROMPT     Затем: echo "$ORACLE_HOME" ; echo "$TNS_ADMIN" ; lsnrctl status
PROMPT     Путь к listener.ora указан в выводе lsnrctl status (файл может отсутствовать).
PROMPT 19. lsnrctl status ; lsnrctl help ; lsnrctl services
PROMPT 20. lsnrctl services
PROMPT     Для удобства: отдельный файл Lab05_Docker_Listener.sh.

-- Аналогичная полезная информация, доступная прямо через SQL Developer:
SELECT name, display_value
FROM v$parameter
WHERE name IN ('instance_name', 'service_names',
               'local_listener', 'remote_listener')
ORDER BY name;

PROMPT
PROMPT ===== ЛАБОРАТОРНАЯ № 5: КОНЕЦ =====
PROMPT 17-20 завершаются проверкой в терминале Arch / внутри Docker.
