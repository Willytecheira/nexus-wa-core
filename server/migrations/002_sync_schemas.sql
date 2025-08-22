-- Schema synchronization migration
-- Version: 002_sync_schemas
-- Purpose: Sync existing schema with migration schema

-- First, check if we need to update the sessions table structure
-- Add missing columns to sessions table if they don't exist

-- Add session_id column if it doesn't exist
ALTER TABLE sessions ADD COLUMN session_id VARCHAR(255);

-- Add qr_code column if it doesn't exist
ALTER TABLE sessions ADD COLUMN qr_code TEXT;

-- Add qr_expires_at column if it doesn't exist
ALTER TABLE sessions ADD COLUMN qr_expires_at DATETIME;

-- Add webhook_url column if it doesn't exist
ALTER TABLE sessions ADD COLUMN webhook_url VARCHAR(500);

-- Add is_active column if it doesn't exist
ALTER TABLE sessions ADD COLUMN is_active BOOLEAN DEFAULT 1;

-- Add created_by column if it doesn't exist
ALTER TABLE sessions ADD COLUMN created_by INTEGER;

-- Add updated_at column if it doesn't exist
ALTER TABLE sessions ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP;

-- Update session_id to match id for existing records
UPDATE sessions SET session_id = id WHERE session_id IS NULL;

-- Rename last_activity to last_active by copying data
UPDATE sessions SET updated_at = last_activity WHERE last_activity IS NOT NULL;

-- Update users table to match migration schema if needed
-- Add missing columns to users table

-- Add email column if it doesn't exist
ALTER TABLE users ADD COLUMN email VARCHAR(255);

-- Add password_hash column if it doesn't exist  
ALTER TABLE users ADD COLUMN password_hash VARCHAR(255);

-- Copy password to password_hash for existing users
UPDATE users SET password_hash = password WHERE password_hash IS NULL;

-- Update messages table to match migration schema
-- Add missing columns to messages table

-- Add message_id column if it doesn't exist
ALTER TABLE messages ADD COLUMN message_id VARCHAR(255);

-- Add chat_id column if it doesn't exist
ALTER TABLE messages ADD COLUMN chat_id VARCHAR(255);

-- Add content column if it doesn't exist
ALTER TABLE messages ADD COLUMN content TEXT;

-- Add is_from_me column if it doesn't exist
ALTER TABLE messages ADD COLUMN is_from_me BOOLEAN DEFAULT 0;

-- Copy message_body to content for existing messages
UPDATE messages SET content = message_body WHERE content IS NULL;

-- Set chat_id to session_id for existing messages if not set
UPDATE messages SET chat_id = session_id WHERE chat_id IS NULL;

-- Create missing indexes for performance
CREATE INDEX IF NOT EXISTS idx_sessions_active ON sessions(is_active);
CREATE INDEX IF NOT EXISTS idx_messages_chat ON messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_contacts_session ON contacts(session_id);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone_number);
CREATE INDEX IF NOT EXISTS idx_webhook_events_session ON webhook_events(session_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_type ON webhook_events(event_type);
CREATE INDEX IF NOT EXISTS idx_metrics_type ON metrics(metric_type);
CREATE INDEX IF NOT EXISTS idx_metrics_recorded ON metrics(recorded_at);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active);