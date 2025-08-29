-- Fix schema and FOREIGN KEY constraints
-- Version: 002_fix_schema_constraints
-- Created: 2025-08-29

-- First, ensure the migration_log table exists
CREATE TABLE IF NOT EXISTS migration_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    migration_name VARCHAR(255) NOT NULL UNIQUE,
    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Add missing columns to sessions table
ALTER TABLE sessions ADD COLUMN connected_at DATETIME;
ALTER TABLE sessions ADD COLUMN messages_sent INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN messages_received INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN connection_time INTEGER DEFAULT 0;
ALTER TABLE sessions ADD COLUMN error_count INTEGER DEFAULT 0;

-- Update sessions table to make user_id NOT NULL constraints more flexible
-- Since we can't modify NOT NULL constraints easily in SQLite, we'll update existing NULL values

-- Create a default system user if it doesn't exist
INSERT OR IGNORE INTO users (id, username, password_hash, role, status) 
VALUES (
    'system', 
    'system', 
    '$2b$10$rBGkrqOQ8kf8gp4hhDf4k.X5/1ZWrWVJ5GkjF7.YK8x7Q9r0qOQzC', 
    'admin',
    'active'
);

-- Update sessions with NULL user_id to use system user
UPDATE sessions SET user_id = 'system' WHERE user_id IS NULL;

-- For messages table, we'll allow NULL user_id but ensure session_id references are valid
-- Update any orphaned messages to reference valid sessions or delete them
DELETE FROM messages WHERE session_id NOT IN (SELECT id FROM sessions);

-- Ensure all messages have a valid session reference
-- If there are still constraint issues, we'll update the foreign key to be more permissive

-- Add indexes for better performance on new columns
CREATE INDEX IF NOT EXISTS idx_sessions_connected_at ON sessions(connected_at);
CREATE INDEX IF NOT EXISTS idx_sessions_messages_sent ON sessions(messages_sent);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);