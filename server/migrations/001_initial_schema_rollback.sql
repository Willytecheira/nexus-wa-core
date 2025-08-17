-- Rollback for initial schema
-- Version: 001_initial_schema

-- Drop all indexes first
DROP INDEX IF EXISTS idx_users_active;
DROP INDEX IF EXISTS idx_api_keys_active;
DROP INDEX IF EXISTS idx_metrics_recorded;
DROP INDEX IF EXISTS idx_metrics_type;
DROP INDEX IF EXISTS idx_webhook_events_type;
DROP INDEX IF EXISTS idx_webhook_events_session;
DROP INDEX IF EXISTS idx_contacts_phone;
DROP INDEX IF EXISTS idx_contacts_session;
DROP INDEX IF EXISTS idx_messages_chat;
DROP INDEX IF EXISTS idx_messages_timestamp;
DROP INDEX IF EXISTS idx_messages_session;
DROP INDEX IF EXISTS idx_sessions_active;
DROP INDEX IF EXISTS idx_sessions_status;

-- Drop all tables in reverse order of dependencies
DROP TABLE IF EXISTS api_keys;
DROP TABLE IF EXISTS metrics;
DROP TABLE IF EXISTS webhook_events;
DROP TABLE IF EXISTS contacts;
DROP TABLE IF EXISTS messages;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS users;