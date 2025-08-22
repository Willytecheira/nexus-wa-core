-- Rollback for schema synchronization
-- Version: 002_sync_schemas

-- Drop added indexes
DROP INDEX IF EXISTS idx_sessions_active;
DROP INDEX IF EXISTS idx_messages_chat;
DROP INDEX IF EXISTS idx_contacts_session;
DROP INDEX IF EXISTS idx_contacts_phone;
DROP INDEX IF EXISTS idx_webhook_events_session;
DROP INDEX IF EXISTS idx_webhook_events_type;
DROP INDEX IF EXISTS idx_metrics_type;
DROP INDEX IF EXISTS idx_metrics_recorded;
DROP INDEX IF EXISTS idx_api_keys_active;
DROP INDEX IF EXISTS idx_users_active;

-- Note: SQLite doesn't support DROP COLUMN, so we cannot rollback column additions
-- This rollback script serves as documentation of what was added
-- To fully rollback, the database would need to be restored from backup

-- Columns added that cannot be dropped in SQLite:
-- sessions: session_id, qr_code, qr_expires_at, webhook_url, is_active, created_by, updated_at
-- users: email, password_hash
-- messages: message_id, chat_id, content, is_from_me