-- Demo accounts for a fresh auth database (idempotent).
-- Password for every account: CallTest#2026
INSERT INTO users (full_name, email, username, password_hash, auth_provider, birth_date, interest)
SELECT 'Call Tester A', 'calltest.a@test.local', 'calltest_a',
       '$2a$10$27TXrU.1a.nkXp0wWsNLk.BJ1q3CLkfInOSklviFXgBJqE3vzuisO',
       'local', '2000-01-01', 'Music'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE lower(email) = lower('calltest.a@test.local'));

INSERT INTO users (full_name, email, username, password_hash, auth_provider, birth_date, interest)
SELECT 'Call Tester B', 'calltest.b@test.local', 'calltest_b',
       '$2a$10$27TXrU.1a.nkXp0wWsNLk.BJ1q3CLkfInOSklviFXgBJqE3vzuisO',
       'local', '2000-01-01', 'Music'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE lower(email) = lower('calltest.b@test.local'));

INSERT INTO users (full_name, email, username, password_hash, auth_provider, birth_date, interest)
SELECT 'Call Tester C', 'calltest.c@test.local', 'calltest_c',
       '$2a$10$27TXrU.1a.nkXp0wWsNLk.BJ1q3CLkfInOSklviFXgBJqE3vzuisO',
       'local', '2000-01-01', 'Music'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE lower(email) = lower('calltest.c@test.local'));

INSERT INTO users (full_name, email, username, password_hash, auth_provider, birth_date, interest)
SELECT 'Call Tester D', 'calltest.d@test.local', 'calltest_d',
       '$2a$10$27TXrU.1a.nkXp0wWsNLk.BJ1q3CLkfInOSklviFXgBJqE3vzuisO',
       'local', '2000-01-01', 'Music'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE lower(email) = lower('calltest.d@test.local'));
