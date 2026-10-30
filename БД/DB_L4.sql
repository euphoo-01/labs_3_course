SHOW CON_NAME;

SELECT name, value FROM v$parameter
WHERE name IN ('db_create_file_dest', 'db_recovery_file_dest', 'spfile', 'diagnostic_dest');

SELECT file_name FROM dba_data_files ORDER BY file_name;



SELECT 'DATAFILE' AS file_type, tablespace_name, file_name,
       bytes AS size_b
FROM dba_data_files
UNION ALL
SELECT 'TEMPFILE', tablespace_name, file_name,
       bytes
FROM dba_temp_files
ORDER BY file_type, tablespace_name, file_name;

CREATE TABLESPACE LSA_QDATA
    DATAFILE '/opt/oracle/oradata/LSA_QDATA.dbf' SIZE 10M
    EXTENT MANAGEMENT LOCAL AUTOALLOCATE
    SEGMENT SPACE MANAGEMENT AUTO
    OFFLINE;

SELECT tablespace_name, status, extent_management, allocation_type
FROM dba_tablespaces
WHERE tablespace_name = 'LSA_QDATA';

CREATE USER LSA IDENTIFIED BY "Lsa123";
GRANT CREATE SESSION, CREATE TABLE TO LSA;

ALTER TABLESPACE LSA_QDATA ONLINE;
ALTER USER LSA QUOTA 2M ON LSA_QDATA;

SELECT username, tablespace_name, max_bytes
FROM dba_ts_quotas
WHERE username = 'LSA' AND tablespace_name = 'LSA_QDATA';

CREATE TABLE LSA_T1 (
    ID NUMBER NOT NULL,
    TXT VARCHAR2(30),
    CONSTRAINT LSA_T1_PK PRIMARY KEY (ID)
        USING INDEX TABLESPACE LSA_QDATA
) TABLESPACE LSA_QDATA;

INSERT INTO LSA_T1 (ID, TXT) VALUES (1, 'A');
INSERT INTO LSA_T1 (ID, TXT) VALUES (2, 'B');
INSERT INTO LSA_T1 (ID, TXT) VALUES (3, 'C');
COMMIT;
SELECT * FROM LSA_T1 ORDER BY ID;

SELECT segment_name, segment_type, tablespace_name,
       bytes, blocks, extents
FROM user_segments
WHERE tablespace_name = 'LSA_QDATA'
ORDER BY segment_type, segment_name;

DROP TABLE LSA_T1;
SELECT segment_name, segment_type, bytes, extents
FROM user_segments
WHERE tablespace_name = 'LSA_QDATA'
ORDER BY segment_name;

SELECT object_name, original_name, type, droptime, can_undrop, space
FROM user_recyclebin
WHERE original_name IN ('LSA_T1', 'LSA_T1_PK')
ORDER BY droptime DESC;

FLASHBACK TABLE LSA_T1 TO BEFORE DROP;
SELECT * FROM LSA_T1 ORDER BY ID;
SELECT object_name, original_name, type FROM user_recyclebin;

BEGIN
    FOR i IN 4..10000 LOOP
        INSERT INTO LSA_T1 (ID, TXT)
        VALUES (i, 'ROW_' || TO_CHAR(i));
    END LOOP;
    COMMIT;
END;
/
SELECT COUNT(*) AS rows_count FROM LSA_T1;

SELECT segment_name, segment_type, extents AS extent_count,
       blocks AS total_blocks, bytes AS total_bytes
FROM user_segments
WHERE segment_name = 'LSA_T1';

SELECT *
FROM user_extents
WHERE segment_name = 'LSA_T1'
ORDER BY extent_id;

SELECT value AS db_block_size_bytes
FROM v$parameter WHERE name = 'db_block_size';

DROP TABLESPACE LSA_QDATA INCLUDING CONTENTS AND DATAFILES CASCADE CONSTRAINTS;

SELECT tablespace_name FROM dba_tablespaces
WHERE tablespace_name = 'LSA_QDATA'; 

SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb,
       members, archived, status, first_change#, next_change#, first_time
FROM v$log
ORDER BY group#;

SELECT group#, type, member, status
FROM v$logfile
ORDER BY group#, member;

SELECT SYSTIMESTAMP AS time_before_first_switch FROM dual;
ALTER SYSTEM SWITCH LOGFILE;
SELECT SYSTIMESTAMP AS time_after_first_switch FROM dual;
SELECT group#, sequence#, status, first_change#, next_change#
FROM v$log ORDER BY group#;

SELECT thread#, sequence#, first_change#, next_change#, first_time
FROM v$log_history
ORDER BY first_time DESC FETCH FIRST 15 ROWS ONLY;
SELECT current_scn FROM v$database;

ALTER DATABASE ADD LOGFILE GROUP 10 (
    '/opt/oracle/oradata/LSA_REDO10_A.log',
    '/opt/oracle/oradata/LSA_REDO10_B.log',
    '/opt/oracle/oradata/LSA_REDO10_C.log'
) SIZE 50M;

SELECT group#, thread#, sequence#, status, first_change#, next_change#
FROM v$log ORDER BY group#;
SELECT group#, member, status FROM v$logfile
WHERE group# = 10 ORDER BY member;

ALTER SYSTEM SWITCH LOGFILE;

SELECT group#, sequence#, status, first_change#, next_change#
FROM v$log ORDER BY group#;

ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
SELECT group#, status, archived FROM v$log WHERE group# = 10;

ALTER DATABASE DROP LOGFILE GROUP 10;
SELECT group#, member FROM v$logfile WHERE group# = 10;

SELECT name, log_mode, current_scn FROM v$database;

SELECT thread#, MAX(sequence#) AS last_archived_sequence
FROM v$archived_log
WHERE name IS NOT NULL AND deleted = 'NO'
GROUP BY thread# ORDER BY thread#;

SELECT thread#, sequence#, name, completion_time
FROM v$archived_log
WHERE name IS NOT NULL AND deleted = 'NO'
ORDER BY completion_time DESC FETCH FIRST 10 ROWS ONLY;

SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS con_name
FROM dual;

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
SELECT log_mode FROM v$database;

SELECT dest_id, status, destination, error
FROM v$archive_dest
WHERE status <> 'INACTIVE';

ALTER SYSTEM ARCHIVE LOG CURRENT;

SELECT thread#, sequence#, first_change#, next_change#,
       completion_time, name
FROM v$archived_log
WHERE name IS NOT NULL AND deleted = 'NO'
ORDER BY completion_time DESC FETCH FIRST 15 ROWS ONLY;

SELECT group#, sequence#, first_change#, next_change#, status
FROM v$log ORDER BY group#;

SELECT dest_id, status, destination
FROM v$archive_dest WHERE status <> 'INACTIVE';


SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;
SELECT log_mode FROM v$database;

SELECT name, status, is_recovery_dest_file
FROM v$controlfile ORDER BY name;

SELECT name, value FROM v$parameter WHERE name = 'control_files';

SELECT type, record_size, records_total, records_used
FROM v$controlfile_record_section ORDER BY type;

SELECT name, dbid, checkpoint_change#, current_scn, log_mode
FROM v$database;

ALTER DATABASE BACKUP CONTROLFILE TO TRACE
    AS '/opt/oracle/oradata/LSA_CONTROLFILE.trc' REUSE;

SELECT name, value FROM v$parameter
WHERE name IN ('spfile', 'db_name', 'instance_name', 'control_files')
ORDER BY name;

CREATE PFILE='/opt/oracle/oradata/LSA_PFILE.ORA' FROM SPFILE;

SELECT instance_name, host_name FROM v$instance;
SELECT value FROM v$parameter WHERE name = 'remote_login_passwordfile';
SELECT username, sysdba, sysoper FROM v$pwfile_users;

SELECT name, value FROM v$diag_info ORDER BY name;
SELECT name, value FROM v$parameter
WHERE name IN ('diagnostic_dest', 'background_dump_dest', 'user_dump_dest');

SELECT value AS diag_alert_dir FROM v$diag_info WHERE name = 'Diag Alert';

SELECT originating_timestamp, message_text
FROM v$diag_alert_ext
WHERE LOWER(message_text) LIKE '%log sequence%'
   OR LOWER(message_text) LIKE '%switch logfile%'
   OR LOWER(message_text) LIKE '%advanced to%'
ORDER BY originating_timestamp DESC FETCH FIRST 50 ROWS ONLY;

SELECT value
FROM v$diag_info;

SELECT tablespace_name FROM dba_tablespaces
WHERE tablespace_name = 'LSA_QDATA';

SELECT file_name FROM dba_data_files
WHERE tablespace_name = 'LSA_QDATA';

SELECT group#, member FROM v$logfile
WHERE member LIKE '%LSA_REDO10_%';

SELECT log_mode FROM v$database;


ALTER SESSION SET CONTAINER = FREEPDB1;

DROP TABLESPACE LSA_QDATA
INCLUDING CONTENTS AND DATAFILES
CASCADE CONSTRAINTS;

DROP TABLE LSA_T1 PURGE;

ALTER SESSION SET CONTAINER = CDB$ROOT;

DROP USER LSA CASCADE;

SELECT group#, status, archived
FROM v$log
WHERE group# = 10;

ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;

SELECT group#, status, archived
FROM v$log
WHERE group# = 10;

SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE NOARCHIVELOG;
ALTER DATABASE OPEN;

SELECT log_mode FROM v$database;

SELECT value
FROM v$parameter
WHERE name = 'undo_tablespace';

SELECT DISTINCT segment_type
FROM dba_segments
ORDER BY segment_type;

SELECT object_name, original_name, type, droptime
FROM user_recyclebin;

SELECT l.group#, l.sequence#, f.member
FROM v$log l
JOIN v$logfile f ON l.group# = f.group#
WHERE l.status = 'CURRENT';

SELECT current_scn
FROM v$database;

SELECT group#, sequence#,
       first_change#, next_change#
FROM v$log;

SELECT thread#, sequence#,
       first_change#, next_change#, name
FROM v$archived_log
ORDER BY sequence#;

SELECT log_mode
FROM v$database;

SELECT thread#, MAX(sequence#) AS last_sequence
FROM v$archived_log
WHERE name IS NOT NULL
  AND deleted = 'NO'
GROUP BY thread#;

SELECT sequence#, name, completion_time
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY completion_time DESC
FETCH FIRST 10 ROWS ONLY;

SHOW PARAMETER CONTROL_FILES;

SHOW PARAMETER UNDO_TABLESPACE;