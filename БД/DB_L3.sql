-- внутри сервиса FREE делал
SHOW CON_NAME;

SELECT name, open_mode
FROM v$pdbs;

SELECT instance_name, version, status, edition
FROM v$instance;

SELECT comp_id, comp_name, version, status
FROM dba_registry
ORDER BY comp_name;

SELECT file_name
FROM cdb_data_files
ORDER BY file_name;

SELECT con_id, name AS file_name
FROM v$datafile
ORDER BY name;

SHOW PARAMETER db_create;

CREATE PLUGGABLE DATABASE LSA_PDB
    ADMIN USER LSA_ADMIN
    IDENTIFIED BY "admin123"
    FILE_NAME_CONVERT = (
        '/opt/oracle/oradata/FREE/pdbseed/',
        '/opt/oracle/oradata/FREE/LSA_PDB/'
    );

SELECT name, open_mode
FROM v$pdbs;


ALTER PLUGGABLE DATABASE LSA_PDB OPEN;

ALTER PLUGGABLE DATABASE LSA_PDB SAVE STATE;

SELECT con_id, name, open_mode
FROM v$pdbs;



-- с этого момента работаю уже внутри  LSA_PDB непосредственно
SHOW CON_NAME;

CREATE TABLESPACE LSA_DATA2
    DATAFILE '/opt/oracle/oradata/FREE/LSA_PDB/lsa_data01_02.dbf'
    SIZE 20M
    AUTOEXTEND ON
    NEXT 10M
    MAXSIZE 200M
    EXTENT MANAGEMENT LOCAL;
    
CREATE TEMPORARY TABLESPACE LSA_DATA_TEMP2
    TEMPFILE '/opt/oracle/oradata/FREE/LSA_PDB/lsa_data_temp01_02.dbf'
    SIZE 20M
    AUTOEXTEND ON
    NEXT 10M
    MAXSIZE 200M
    EXTENT MANAGEMENT LOCAL;
    
SELECT tablespace_name, status, contents
FROM dba_tablespaces;

CREATE ROLE LSA_ROLE2;

GRANT CREATE SESSION, CREATE TABLE TO LSA_ROLE2;

CREATE PROFILE LSA_PROFILE2 LIMIT
    FAILED_LOGIN_ATTEMPTS 5
    PASSWORD_LOCK_TIME 1/24
    PASSWORD_LIFE_TIME 90;
    
SELECT profile, resource_name, limit
FROM dba_profiles
WHERE profile = 'LSA_PROFILE2';

CREATE USER USER_LSA_PDB2
    IDENTIFIED BY "user123"
    DEFAULT TABLESPACE LSA_DATA2
    TEMPORARY TABLESPACE LSA_DATA_TEMP2
    QUOTA 20M ON LSA_DATA2
    PROFILE LSA_PROFILE2
    ACCOUNT UNLOCK;

GRANT LSA_ROLE2 TO USER_LSA_PDB2;

-- дальше работаем от имени USER_LSA_PDB
CREATE TABLE LSA_TABLE (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    age NUMBER
);

SELECT * FROM USER_TABLES;

INSERT INTO LSA_TABLE (id, name, age)
VALUES (1, 'Stasyan', 20);
INSERT INTO LSA_TABLE (id, name, age)
VALUES (2, 'Petya', 21);
INSERT INTO LSA_TABLE (id, name, age)
VALUES (3, 'Egorka', 19);
COMMIT;

SELECT * FROM LSA_TABLE;

-- переключился на LSA_ADMIN
SELECT *
FROM dba_tablespaces
ORDER BY tablespace_name;

SELECT tablespace_name,
       file_name,
       bytes / 1024 / 1024 AS size_mb
FROM dba_data_files
UNION
SELECT tablespace_name,
       file_name,
       bytes / 1024 / 1024 AS size_mb
FROM dba_temp_files;

SELECT role
FROM dba_roles;

SELECT grantee, privilege, admin_option
FROM dba_sys_privs
ORDER BY grantee, privilege;

SELECT grantee, privilege, admin_option
FROM dba_sys_privs
WHERE grantee = 'LSA_ROLE2';

SELECT profile,
       resource_name,
       resource_type,
       limit
FROM dba_profiles
ORDER BY profile, resource_name;

SELECT username,
       account_status,
       default_tablespace,
       temporary_tablespace,
       profile,
       created
FROM dba_users;

SELECT grantee,
       granted_role,
       admin_option,
       default_role
FROM dba_role_privs
ORDER BY grantee, granted_role;

SELECT username,
       tablespace_name,
       max_bytes
FROM dba_ts_quotas
WHERE username = 'USER_LSA_PDB2';

-- переключился на админа CDB
SHOW CON_NAME;

CREATE USER C##LSA2
    IDENTIFIED BY "user123"
    CONTAINER = ALL;
    
SELECT con_id, username, common
FROM cdb_users
WHERE username = 'C##LSA2'
ORDER BY con_id;

GRANT CREATE SESSION TO C##LSA2 CONTAINER = ALL;

SELECT grantee, privilege, common
FROM dba_sys_privs
WHERE grantee = 'C##LSA2';

-- переключаюсь на shared пользователя в сервис FREE и в PDB свою
SHOW CON_NAME;

-- переключился на админа cdb
SELECT 'DATAFILE', name
FROM v$datafile
WHERE con_id = (
    SELECT con_id
    FROM v$pdbs
    WHERE name = 'LSA_PDB'
)
UNION
SELECT 'TEMPFILE', name
FROM v$tempfile
WHERE con_id = (
    SELECT con_id
    FROM v$pdbs
    WHERE name = 'LSA_PDB'
);

ALTER PLUGGABLE DATABASE LSA_PDB CLOSE IMMEDIATE;

SELECT name, open_mode
FROM v$pdbs
WHERE name = 'LSA_PDB';

DROP PLUGGABLE DATABASE LSA_PDB
INCLUDING DATAFILES;

SELECT name, open_mode
FROM v$pdbs;

DROP USER C##LSA;


