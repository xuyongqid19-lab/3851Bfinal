ALTER TABLE group_members ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'member';
ALTER TABLE group_members ADD COLUMN IF NOT EXISTS is_muted boolean NOT NULL DEFAULT false;
UPDATE group_members gm SET role = 'owner' FROM group_chats gc WHERE gm.group_id = gc.id AND gm.user_id = gc.created_by AND gm.role = 'member';
