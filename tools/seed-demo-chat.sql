-- Demo friendships and group for a fresh chat database (idempotent).
-- User ids match tools/seed-demo-auth.sql.

INSERT INTO chat_users (user_id, full_name, username, email, google_photo_url, interest, auth_provider, updated_at)
SELECT 'd0c162b2-7255-47d1-bda3-f0d3c984393a', 'Call Tester A', 'calltest_a', 'calltest.a@test.local', NULL, 'Music', 'local', now()
WHERE NOT EXISTS (SELECT 1 FROM chat_users WHERE user_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a');

INSERT INTO chat_users (user_id, full_name, username, email, google_photo_url, interest, auth_provider, updated_at)
SELECT 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b', 'Call Tester B', 'calltest_b', 'calltest.b@test.local', NULL, 'Music', 'local', now()
WHERE NOT EXISTS (SELECT 1 FROM chat_users WHERE user_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b');

INSERT INTO chat_users (user_id, full_name, username, email, google_photo_url, interest, auth_provider, updated_at)
SELECT 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e', 'Call Tester C', 'calltest_c', 'calltest.c@test.local', NULL, 'Music', 'local', now()
WHERE NOT EXISTS (SELECT 1 FROM chat_users WHERE user_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e');

INSERT INTO chat_users (user_id, full_name, username, email, google_photo_url, interest, auth_provider, updated_at)
SELECT '3458bcca-c746-4f54-a5db-7bb20b96818d', 'Call Tester D', 'calltest_d', 'calltest.d@test.local', NULL, 'Music', 'local', now()
WHERE NOT EXISTS (SELECT 1 FROM chat_users WHERE user_id = '3458bcca-c746-4f54-a5db-7bb20b96818d');

INSERT INTO friendships (requester_id, addressee_id, status, message)
SELECT 'd0c162b2-7255-47d1-bda3-f0d3c984393a', 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b', 'accepted', 'demo seed'
WHERE NOT EXISTS (
  SELECT 1 FROM friendships
  WHERE (requester_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a' AND addressee_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b')
     OR (requester_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b' AND addressee_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a')
);

INSERT INTO friendships (requester_id, addressee_id, status, message)
SELECT 'd0c162b2-7255-47d1-bda3-f0d3c984393a', 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e', 'accepted', 'demo seed'
WHERE NOT EXISTS (
  SELECT 1 FROM friendships
  WHERE (requester_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a' AND addressee_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e')
     OR (requester_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e' AND addressee_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a')
);

INSERT INTO friendships (requester_id, addressee_id, status, message)
SELECT 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b', 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e', 'accepted', 'demo seed'
WHERE NOT EXISTS (
  SELECT 1 FROM friendships
  WHERE (requester_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b' AND addressee_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e')
     OR (requester_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e' AND addressee_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b')
);

INSERT INTO group_chats (id, name, created_by)
SELECT 'b7d328d6-781c-4b7e-b259-e47cfa2404a6', 'Group Call Demo', 'd0c162b2-7255-47d1-bda3-f0d3c984393a'
WHERE NOT EXISTS (SELECT 1 FROM group_chats WHERE id = 'b7d328d6-781c-4b7e-b259-e47cfa2404a6');

INSERT INTO group_members (group_id, user_id, role)
SELECT 'b7d328d6-781c-4b7e-b259-e47cfa2404a6', 'd0c162b2-7255-47d1-bda3-f0d3c984393a', 'owner'
WHERE NOT EXISTS (
  SELECT 1 FROM group_members
  WHERE group_id = 'b7d328d6-781c-4b7e-b259-e47cfa2404a6'
    AND user_id = 'd0c162b2-7255-47d1-bda3-f0d3c984393a'
);

INSERT INTO group_members (group_id, user_id, role)
SELECT 'b7d328d6-781c-4b7e-b259-e47cfa2404a6', 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b', 'member'
WHERE NOT EXISTS (
  SELECT 1 FROM group_members
  WHERE group_id = 'b7d328d6-781c-4b7e-b259-e47cfa2404a6'
    AND user_id = 'cf49ee9e-1fb3-4b1f-a92c-0b1dde393a8b'
);

INSERT INTO group_members (group_id, user_id, role)
SELECT 'b7d328d6-781c-4b7e-b259-e47cfa2404a6', 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e', 'member'
WHERE NOT EXISTS (
  SELECT 1 FROM group_members
  WHERE group_id = 'b7d328d6-781c-4b7e-b259-e47cfa2404a6'
    AND user_id = 'bbaf53bf-d6ae-4c24-bd08-a35e679f276e'
);
