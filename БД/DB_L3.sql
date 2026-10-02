SELECT NAME, OPEN_MODE
FROM v$pdbs;

SELECT *
FROM v$instance;

SELECT comp_name,
       version,
       status
FROM dba_registry
ORDER BY comp_name;