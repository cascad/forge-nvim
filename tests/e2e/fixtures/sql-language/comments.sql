-- leading line comment; not another statement
SELECT name AS line_comment_result FROM users WHERE id = 1;
/* comment before write; preserve the real SQL */
UPDATE counters SET value = value + 4;
/* comment before query */
SELECT '/* literal */ -- 😀;ю' AS literal_comment_result, name FROM users WHERE id = 1;
-- trailing comment
