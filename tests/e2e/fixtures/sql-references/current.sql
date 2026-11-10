-- id, users.id, u.id and accounts.id are not references here.
SELECT '😀 id u.id' AS marker, u.id, a.id
FROM users AS u
JOIN accounts AS a ON a.owner_id = u.id
WHERE u.id > 0 AND a.id > 0;

SELECT id FROM users JOIN accounts ON users.id = accounts.id;
