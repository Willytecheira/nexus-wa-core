-- Rollback for schema and constraint fixes
-- Version: 002_fix_schema_constraints

-- Drop added indexes
DROP INDEX IF EXISTS idx_sessions_user_id;
DROP INDEX IF EXISTS idx_sessions_messages_sent;
DROP INDEX IF EXISTS idx_sessions_connected_at;

-- Note: SQLite doesn't support DROP COLUMN, so we can't easily rollback column additions
-- In a production environment, you would need to recreate the table without these columns
-- For now, we'll just comment what would need to be done:

-- Would need to:
-- 1. Create new sessions table without the added columns
-- 2. Copy data from old table to new table
-- 3. Drop old table and rename new table

-- Remove system user if it was created by this migration
DELETE FROM users WHERE id = 'system' AND username = 'system';