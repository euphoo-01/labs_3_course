-- ЛР 4. Исследование архитектуры: файлы Oracle.
-- Подготовлено по Лабораторная_04.doc. Исходный DB_L4.sql сохранён.
-- Выполнять ПО РАЗДЕЛАМ, не запускать весь файл одним F5!
-- Окружение: docker oracle-db, CDB FREE, PDB FREEPDB1, префикс LSA.
-- Если имена/пути отличаются, сначала исправить их по результатам раздела 0.
-- SYS AS SYSDBA: административные разделы. LSA: разделы 2–5.
-- EX: на общем сервере выполнять по очереди. Перезапуск затрагивает всю CDB.
-- Команды SHOW, VARIABLE, PRINT, EXEC — команды SQL*Plus/SQLcl и script mode SQL Developer.
-- Команды ОС ниже даны в комментариях, выполнять в отдельном терминале.

-- 0. SYS AS SYSDBA, сервис FREE. Проверить среду и сохранить исходные значения.
SHOW USER
SHOW CON_NAME
SELECT instance_name, version, status FROM v$instance;
SELECT name, open_mode, log_mode, current_scn FROM v$database;
SELECT con_id, name, open_mode FROM v$pdbs;
SELECT name, value FROM v$parameter
WHERE name IN ('db_create_file_dest','db_recovery_file_dest','spfile',
               'control_files','log_archive_dest_1','log_archive_format');
-- ОС: docker exec -it oracle-db bash
-- ОС внутри контейнера: sqlplus / as sysdba
-- Для SHUTDOWN/STARTUP ниже использовать именно локальный sqlplus / as sysdba.

-- 1. SYS, FREEPDB1. Файлы перманентных и временных пространств этой PDB.
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT 'DATAFILE' AS file_type, tablespace_name, file_name, bytes
FROM dba_data_files
UNION ALL
SELECT 'TEMPFILE', tablespace_name, file_name, bytes FROM dba_temp_files
ORDER BY file_type, tablespace_name, file_name;
-- Все контейнеры: в CDB$ROOT аналогично CDB_DATA_FILES/CDB_TEMP_FILES с CON_ID.
CREATE TABLESPACE LSA_QDATA
  DATAFILE '/opt/oracle/oradata/LSA_QDATA.dbf' SIZE 10M
  EXTENT MANAGEMENT LOCAL AUTOALLOCATE
  SEGMENT SPACE MANAGEMENT AUTO OFFLINE;
SELECT tablespace_name, status, contents, extent_management, allocation_type
FROM dba_tablespaces WHERE tablespace_name = 'LSA_QDATA';
ALTER TABLESPACE LSA_QDATA ONLINE;
-- Если LSA уже существует, CREATE USER пропустить; не менять существующий пароль.
CREATE USER LSA IDENTIFIED BY "LsaLab4_2026";
GRANT CREATE SESSION, CREATE TABLE TO LSA;
ALTER USER LSA QUOTA 2M ON LSA_QDATA;
SELECT username, tablespace_name, bytes, max_bytes FROM dba_ts_quotas
WHERE username = 'LSA' AND tablespace_name = 'LSA_QDATA';
SHOW PARAMETER recyclebin
-- Если OFF: включить в сессии LSA перед DROP: ALTER SESSION SET recyclebin = ON;

-- 2. НОВОЕ подключение LSA, сервис FREEPDB1. SET CONTAINER не меняет пользователя!
-- В SQL Developer создать отдельное подключение: localhost:1521/FREEPDB1.
SHOW USER
SHOW CON_NAME
CREATE TABLE LSA_T1 (
  id NUMBER NOT NULL,
  txt VARCHAR2(30),
  CONSTRAINT LSA_T1_PK PRIMARY KEY (id) USING INDEX TABLESPACE LSA_QDATA
) TABLESPACE LSA_QDATA;
INSERT INTO LSA_T1 VALUES (1, 'A');
INSERT INTO LSA_T1 VALUES (2, 'B');
INSERT INTO LSA_T1 VALUES (3, 'C');
COMMIT;
SELECT * FROM LSA_T1 ORDER BY id;

-- 3. Сегмент таблицы и отдельный сегмент индекса первичного ключа.
SELECT segment_name, segment_type, bytes, blocks, extents
FROM user_segments WHERE tablespace_name = 'LSA_QDATA'
ORDER BY segment_type, segment_name;
SELECT index_name, table_name, tablespace_name FROM user_indexes
WHERE table_name = 'LSA_T1';

-- 4. Корзина и восстановление. Не использовать PURGE до FLASHBACK.
ALTER SESSION SET recyclebin = ON;
DROP TABLE LSA_T1;
SELECT segment_name, segment_type, bytes, extents FROM user_segments
WHERE tablespace_name = 'LSA_QDATA';
SELECT object_name, original_name, type, droptime, can_undrop, space
FROM user_recyclebin WHERE original_name IN ('LSA_T1','LSA_T1_PK');
FLASHBACK TABLE LSA_T1 TO BEFORE DROP;
SELECT * FROM LSA_T1 ORDER BY id;
SELECT object_name, original_name, type FROM user_recyclebin;

-- 5. Получить ИТОГО 10000 строк: три уже есть, добавляем 9997.
BEGIN
  FOR i IN 4..10000 LOOP
    INSERT INTO LSA_T1 VALUES (i, 'ROW_' || TO_CHAR(i));
  END LOOP;
  COMMIT;
END;
/
SELECT COUNT(*) AS rows_count FROM LSA_T1;
SELECT segment_name, extents, blocks, bytes FROM user_segments
WHERE segment_name = 'LSA_T1';
SELECT extent_id, file_id, block_id, blocks, bytes FROM user_extents
WHERE segment_name = 'LSA_T1' ORDER BY extent_id;
SELECT COUNT(*) AS extent_count, SUM(blocks) AS blocks, SUM(bytes) AS bytes
FROM user_extents WHERE segment_name = 'LSA_T1';
-- Повторять вставку нельзя: будут повторные первичные ключи.

-- 6. SYS, FREEPDB1. Удалить пространство вместе с файлом.
SELECT tablespace_name, block_size FROM dba_tablespaces
WHERE tablespace_name = 'LSA_QDATA';
DROP TABLESPACE LSA_QDATA INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;
SELECT tablespace_name FROM dba_tablespaces WHERE tablespace_name = 'LSA_QDATA';
SELECT file_name FROM dba_data_files WHERE tablespace_name = 'LSA_QDATA';
-- ОС: ls -l /opt/oracle/oradata/LSA_QDATA.dbf  (ожидается отсутствие).
-- Только если LSA создан именно для этой работы и не содержит нужных объектов:
-- DROP USER LSA;

-- 7–8. SYS, CDB$ROOT. Группы и физические файлы redo.
ALTER SESSION SET CONTAINER = CDB$ROOT;
SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       members, archived, status, first_change#, next_change#
FROM v$log ORDER BY group#;
SELECT group#, type, member, status FROM v$logfile ORDER BY group#, member;
SELECT l.group#, l.sequence#, f.member FROM v$log l
JOIN v$logfile f ON f.group# = l.group# WHERE l.status = 'CURRENT';

-- 9. EX. Полный цикл: число переключений равно числу групп (single-instance).
-- Переменная сохранится только в текущей сессии; также записать время отдельно.
VARIABLE first_switch VARCHAR2(80)
EXEC :first_switch := TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF TZH:TZM');
PRINT first_switch
DECLARE
  n PLS_INTEGER;
BEGIN
  SELECT COUNT(*) INTO n FROM v$log;
  FOR i IN 1..n LOOP
    EXECUTE IMMEDIATE 'ALTER SYSTEM SWITCH LOGFILE';
  END LOOP;
END;
/
SELECT group#, sequence#, status, first_change#, next_change# FROM v$log ORDER BY group#;
SELECT thread#, sequence#, first_change#, next_change#, first_time
FROM v$log_history ORDER BY first_time DESC FETCH FIRST 20 ROWS ONLY;

-- 10. EX. Группа 10 должна быть свободна; пути не должны уже существовать.
-- Размер не меньше допустимого в вашей версии (50M подходит для учебного примера).
SELECT group# FROM v$log WHERE group# = 10;
ALTER DATABASE ADD LOGFILE GROUP 10 (
 '/opt/oracle/oradata/LSA_REDO10_A.log',
 '/opt/oracle/oradata/LSA_REDO10_B.log',
 '/opt/oracle/oradata/LSA_REDO10_C.log') SIZE 50M;
SELECT group#, member FROM v$logfile WHERE group# = 10;
-- Повторять следующие ДВА запроса, пока group# 10 не станет CURRENT.
ALTER SYSTEM SWITCH LOGFILE;
SELECT group#, sequence#, status, first_change#, next_change# FROM v$log ORDER BY group#;
-- Зафиксировать CURRENT группы 10: это демонстрация её использования.

-- 11. EX. После CURRENT переключиться с группы 10 и сделать checkpoint.
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
SELECT group#, status, archived FROM v$log WHERE group# = 10;
-- DROP выполнять только при INACTIVE (или UNUSED).
-- При ARCHIVELOG также требуется архивирование использованной группы.
-- Если ACTIVE: повторить CHECKPOINT и проверку, при необходимости дождаться.
ALTER DATABASE DROP LOGFILE GROUP 10;
SELECT group#, member FROM v$logfile WHERE group# = 10;
-- Только после успешного DROP и пустого результата удалить ТРИ своих файла ОС:
-- rm -- /opt/oracle/oradata/LSA_REDO10_A.log /opt/oracle/oradata/LSA_REDO10_B.log /opt/oracle/oradata/LSA_REDO10_C.log

-- 12–13. Режим архивирования и последний архив текущей инкарнации.
SELECT log_mode, resetlogs_change# FROM v$database;
-- По заданию исходно требуется NOARCHIVELOG. На общем сервере дождаться своей очереди.
SELECT thread#, MAX(sequence#) AS last_archived_sequence FROM v$archived_log
WHERE name IS NOT NULL AND deleted = 'NO'
  AND resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
GROUP BY thread#;
-- Пусто = нет зарегистрированных подходящих архивов, не ошибка.

-- 14–15. EX. Локальный SQL*Plus / AS SYSDBA, CDB$ROOT. Перезапуск всей БД!
-- Заранее в ОС создать НОВОЙ пустую личную директорию от пользователя oracle:
-- mkdir /opt/oracle/oradata/LSA_L4_ARCH
-- Сохранить исходное значение LOG_ARCHIVE_DEST_1 из раздела 0.
-- Личный каталог упрощает точную очистку созданных архивов.
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/LSA_L4_ARCH' SCOPE=MEMORY;
-- SCOPE=MEMORY теряется при рестарте, поэтому после OPEN назначаем снова.
SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE ARCHIVELOG;
-- Назначение должно действовать ДО OPEN и первого архивирования.
ALTER SYSTEM SET log_archive_dest_1='LOCATION=/opt/oracle/oradata/LSA_L4_ARCH' SCOPE=MEMORY;
ALTER DATABASE OPEN;
ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
-- Если PDB уже открыта автоматически, OPEN пропустить.
SELECT log_mode FROM v$database;
SELECT dest_id, status, destination, error FROM v$archive_dest WHERE status <> 'INACTIVE';
ALTER SYSTEM ARCHIVE LOG CURRENT;
SELECT thread#, sequence#, first_change#, next_change#, completion_time, name
FROM v$archived_log WHERE name IS NOT NULL AND deleted = 'NO'
 AND resetlogs_change# = (SELECT resetlogs_change# FROM v$database)
ORDER BY completion_time DESC FETCH FIRST 20 ROWS ONLY;
SELECT group#, sequence#, first_change#, next_change#, status FROM v$log ORDER BY group#;
-- ОС: ls -lh /opt/oracle/oradata/LSA_L4_ARCH
-- Сопоставлять THREAD#, SEQUENCE#, RESETLOGS_CHANGE#; SCN-интервалы [first,next).

-- 16. EX. Вернуть NOARCHIVELOG. При рестарте возвращаются исходные SPFILE-параметры.
SHUTDOWN IMMEDIATE
STARTUP MOUNT
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;
-- При необходимости открыть те PDB, которые были открыты до работы.
SELECT log_mode FROM v$database;
SELECT name, value FROM v$parameter WHERE name = 'log_archive_dest_1';
-- Если исходное значение задавалось только в памяти, восстановить его отдельно.
-- Очистка личных архивов: в терминале контейнера запустить rman target /
-- RMAN> LIST ARCHIVELOG LIKE '/opt/oracle/oradata/LSA_L4_ARCH/%';
-- Сверить список: только архивы своей лабораторной. Затем в RMAN:
-- DELETE ARCHIVELOG LIKE '/opt/oracle/oradata/LSA_L4_ARCH/%';
-- ОС: rmdir /opt/oracle/oradata/LSA_L4_ARCH
-- Не удалять чужие архивы или все архивы через DELETE ARCHIVELOG ALL.

-- 17–18. Управляющие файлы: бинарные, исследуем через представления и trace.
SELECT name, status, is_recovery_dest_file FROM v$controlfile;
SHOW PARAMETER control_files
SELECT type, record_size, records_total, records_used
FROM v$controlfile_record_section ORDER BY type;
SELECT name, dbid, checkpoint_change#, current_scn, log_mode FROM v$database;
ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS '/opt/oracle/oradata/LSA_CONTROLFILE.trc';
-- ОС: cat /opt/oracle/oradata/LSA_CONTROLFILE.trc
-- Trace — текстовый сценарий восстановления структуры, не дамп всех бинарных записей.

-- 19–20. Файл параметров и текстовая копия.
SHOW PARAMETER spfile
SELECT name, value FROM v$parameter
WHERE name IN ('db_name','instance_name','db_block_size','undo_tablespace',
 'sga_target','pga_aggregate_target','control_files','diagnostic_dest');
CREATE PFILE='/opt/oracle/oradata/LSA_PFILE.ORA' FROM SPFILE;
-- ОС: ls -l <точный путь из SHOW PARAMETER spfile>
-- ОС: cat /opt/oracle/oradata/LSA_PFILE.ORA
-- Обратная операция (пример, НЕ выполнять для действующего SPFILE):
-- CREATE SPFILE='/tmp/LSA_SPFILE.ora' FROM PFILE='/opt/oracle/oradata/LSA_PFILE.ORA';

-- 21. Password file. Представление доступно начиная с Oracle 12.2.
SELECT file_name, format, is_asm FROM v$passwordfile_info;
SHOW PARAMETER remote_login_passwordfile
SELECT username, sysdba, sysoper FROM v$pwfile_users;
-- ОС: ls -l <точный FILE_NAME>. Файл бинарный, cat не нужен.

-- 22–23. Диагностика и переключения журналов.
SELECT name, value FROM v$diag_info ORDER BY name;
SELECT name, value FROM v$parameter
WHERE name IN ('diagnostic_dest','background_dump_dest','user_dump_dest');
-- Diag Alert — каталог XML alert log (log.xml), Diag Trace — текстовый alert_<SID>.log.
-- Вставить записанное в разделе 9 время сервера вместо примера ниже.
SELECT originating_timestamp, message_text FROM v$diag_alert_ext
WHERE originating_timestamp >= TO_TIMESTAMP_TZ(
 '2026-10-28 00:00:00 +03:00','YYYY-MM-DD HH24:MI:SS TZH:TZM')
 AND (LOWER(message_text) LIKE '%advanced to log sequence%'
   OR LOWER(message_text) LIKE '%switch logfile%'
   OR LOWER(message_text) LIKE '%log switch%')
ORDER BY originating_timestamp;
-- ОС: less <Diag Alert>/log.xml
-- Время в XML может иметь другой часовой пояс: сравнивать с учётом смещения.

-- 24. Финальная проверка: запросы должны показать отсутствие своих объектов/файлов.
SELECT group#, member FROM v$logfile WHERE member LIKE '%LSA_REDO10_%';
SELECT log_mode FROM v$database;
SELECT name, deleted FROM v$archived_log
WHERE name LIKE '/opt/oracle/oradata/LSA_L4_ARCH/%';
-- После RMAN ожидается DELETED=YES у соответствующих записей.
ALTER SESSION SET CONTAINER = FREEPDB1;
SELECT tablespace_name FROM dba_tablespaces WHERE tablespace_name='LSA_QDATA';
SELECT file_name FROM dba_data_files WHERE tablespace_name='LSA_QDATA';
-- ОС после просмотра удалить только свои текстовые копии:
-- rm -- /opt/oracle/oradata/LSA_CONTROLFILE.trc /opt/oracle/oradata/LSA_PFILE.ORA
-- Проверить отсутствие этих файлов и трёх LSA_REDO10_*.log через ls.
-- Рабочие controlfile, spfile, password file, log.xml НЕ являются созданными копиями.
