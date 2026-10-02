CREATE TABLE LSA_t (
    x NUMBER(3),
    s VARCHAR2(50)
)

INSERT INTO LSA_t (x, s)
VALUES (1, 'aaaaa'), (2, 'bbbbb'), (3, 'cccccc');
COMMIT;

SELECT x, s FROM LSA_t 
ORDER BY x;

UPDATE LSA_t
SET s = 'lsieajf'
WHERE x IN (1,2);
COMMIT;

SELECT x, s
FROM LSA_t
WHERE x >= 2
ORDER BY x;

SELECT x, s
FROM LSA_t
WHERE s LIKE '%a%';

SELECT COUNT(*),
    SUM(x),
    AVG(x),
    MIN(x),
    MAX(x)
FROM LSA_t;

SELECT s, COUNT(*)
FROM LSA_t
GROUP BY s
HAVING COUNT(*) >= 1
ORDER BY s;
    
    
DELETE FROM LSA_t
WHERE x = 3;
COMMIT;

SELECT x, s
FROM LSA_t
ORDER BY x;

ALTER TABLE LSA_t
ADD CONSTRAINT LSA_t_pk PRIMARY KEY (x);

CREATE TABLE LSA_t1 (
    id NUMBER(3),
    x NUMBER(3),
    s VARCHAR2(50),
    
    CONSTRAINT LSA_t1_pk PRIMARY KEY (id),
    
    CONSTRAINT LSA_t1_fk 
    FOREIGN KEY (x)
    REFERENCES LSA_t (x)
);

INSERT INTO LSA_t1 (id, x, s)
VALUES (1, 1, 'sldkfj'), (2, 2, 'woeiru'), (3, NULL, 'pqwoei');    
COMMIT;

SELECT id, x, s
FROM LSA_t1;

SELECT id, x, s
FROM LSA_t1
WHERE x IS NULL;

SELECT a.x, a.s, b.id, b.x, b.s
FROM LSA_t a
INNER JOIN LSA_t1 b
    ON a.x = b.x
ORDER BY a.x, b.id;

SELECT a.x, a.s, b.id, b.x, b.s
FROM LSA_t a
LEFT JOIN LSA_t1 b
    ON a.x = b.x
ORDER BY a.x, b.id;

SELECT a.x, a.s, b.id, b.x, b.s
FROM LSA_t a
RIGHT JOIN LSA_t1 b
    ON a.x = b.x
ORDER BY a.x, b.id;

DROP TABLE LSA_t1;
DROP TABLE LSA_t;