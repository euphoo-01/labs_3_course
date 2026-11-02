-- 1. Общий размер SGA в МБ
SELECT SUM(value) / 1024 / 1024 AS sga_mb
FROM v$sga;

-- 2. Текущие размеры компонентов SGA в МБ
SELECT component, current_size / 1024 / 1024 AS size_mb
FROM v$sga_dynamic_components;

-- 3. Размер гранулы для каждого компонента в МБ
SELECT component, granule_size / 1024 / 1024 AS granule_mb
FROM v$sga_dynamic_components;

-- 4. Свободная память SGA в МБ
SELECT name, bytes / 1024 / 1024 AS free_mb
FROM v$sgainfo
WHERE name = 'Free SGA Memory Available';

-- 5. Максимальный и целевой размер SGA
SELECT name, value
FROM v$parameter
WHERE name IN ('sga_max_size', 'sga_target');

-- 6. Размеры пулов буферного кэша в МБ
-- Отдельный KEEP или RECYCLE может быть не настроен и отсутствовать в списке.
SELECT name, current_size
FROM v$buffer_pool
WHERE name IN ('KEEP', 'DEFAULT', 'RECYCLE');

-- 7. Таблица для пула KEEP и её сегмент
-- Если DB_KEEP_CACHE_SIZE = 0, отдельный пул KEEP не настроен.
-- При повторном запуске CREATE TABLE сообщит, что таблица уже существует.
CREATE TABLE lab05_keep (
    id NUMBER,
    note VARCHAR2(100)
) STORAGE (BUFFER_POOL KEEP);

INSERT INTO lab05_keep VALUES (1, 'KEEP');
COMMIT;

SELECT segment_name, segment_type, buffer_pool, blocks
FROM user_segments
WHERE segment_name = 'LAB05_KEEP';

-- 8. Кэшируемая таблица для пула DEFAULT и её сегмент
CREATE TABLE lab05_default (
    id NUMBER,
    note VARCHAR2(100)
) STORAGE (BUFFER_POOL DEFAULT);

ALTER TABLE lab05_default CACHE;

INSERT INTO lab05_default VALUES (1, 'DEFAULT');
COMMIT;

SELECT segment_name, segment_type, buffer_pool, blocks
FROM user_segments
WHERE segment_name = 'LAB05_DEFAULT';

-- 9. Размер буфера журналов повтора в МБ
SELECT name, bytes / 1024 / 1024 AS redo_buffer_mb
FROM v$sgainfo
WHERE name = 'Redo Buffers';

-- 10. Свободная память в large pool в МБ
SELECT pool, name, bytes / 1024 / 1024 AS free_mb
FROM v$sgastat
WHERE pool = 'large pool' AND name = 'free memory';

-- 11. Режимы пользовательских соединений
SELECT sid, username, server
FROM v$session
WHERE type = 'USER' AND username IS NOT NULL;

-- 12. Работающие фоновые процессы
SELECT b.name, b.description, p.spid
FROM v$bgprocess b
JOIN v$process p ON b.paddr = p.addr;

-- 13. Серверные процессы пользовательских сессий
SELECT s.sid, s.username, s.server, p.spid, p.program
FROM v$session s
JOIN v$process p ON s.paddr = p.addr
WHERE s.type = 'USER' AND s.username IS NOT NULL;

-- При shared server общие серверные процессы можно посмотреть отдельно.
SELECT name, status, requests
FROM v$shared_server;

-- 14. Количество работающих процессов DBWn
SELECT COUNT(*) AS dbwn_count
FROM v$bgprocess b
JOIN v$process p ON b.paddr = p.addr
WHERE b.name LIKE 'DBW_';

-- 15. Сервисы базы данных
SELECT name, network_name
FROM v$services;

-- 16. Параметры диспетчеров и shared server
SELECT name, value
FROM v$parameter
WHERE name IN ('dispatchers', 'shared_servers', 'max_shared_servers');

SELECT name, status, network
FROM v$dispatcher;

-- docker ps
-- docker exec -it oracle-db sh
-- ps -ef | grep '[t]nslsnr'
-- lsnrctl status
-- lsnrctl services
-- lsnrctl help
-- cat "$ORACLE_HOME/network/admin/listener.ora"