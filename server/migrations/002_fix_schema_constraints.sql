-- Fix schema and add missing columns for message tracking
-- Version: 002_fix_schema_constraints
-- Created: 2025-08-29

-- Add missing columns to sessions table if they don't exist
ALTER TABLE sessions ADD COLUMN connected_at DATETIME;
ALTER TABLE sessions ADD COLUMN messages_sent INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN messages_received INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN connection_time INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN error_count INTEGER DEFAULT 0;

-- Create a default system user if it doesn't exist
INSERT OR IGNORE INTO users (id, username, password_hash, role, status, created_at) 
VALUES (
    'system', 
    'system', 
    '$2b$10$rBGkrqOQ8kf8gp4hhDf4k.X5/1ZWrWVJ5GkjF7.YK8x7Q9r0qOQzC', 
    'admin',
    'active',
    CURRENT_TIMESTAMP
);

-- Update sessions with NULL user_id to use system user
UPDATE sessions SET user_id = 'system' WHERE user_id IS NULL OR user_id = '';

-- Clean up orphaned messages (messages without valid session references)
DELETE FROM messages WHERE session_id NOT IN (SELECT id FROM sessions);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_sessions_connected_at ON sessions(connected_at);
CREATE INDEX IF NOT EXISTS idx_sessions_messages_sent ON sessions(messages_sent);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);