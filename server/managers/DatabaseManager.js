const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs-extra');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

class DatabaseManager {
  constructor() {
    this.db = null;
    this.dbPath = path.join(__dirname, '..', 'database', 'whatsapp_api.db');
  }

  async initialize() {
    try {
      // Ensure database directory exists
      await fs.ensureDir(path.dirname(this.dbPath));

      // Create database connection
      this.db = new sqlite3.Database(this.dbPath);

      // Enable foreign keys
      await this.run('PRAGMA foreign_keys = ON');

      // Create tables
      await this.createTables();

      logger.info('Database initialized successfully');
    } catch (error) {
      logger.error('Database initialization failed:', error);
      throw error;
    }
  }

  async createTables() {
    const tables = [
      // Users table
      `CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin', 'operator', 'viewer')),
        status TEXT NOT NULL CHECK (status IN ('active', 'inactive')) DEFAULT 'active',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_login DATETIME,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )`,

      // Sessions table
      `CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        phone_number TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        last_activity DATETIME,
        user_id TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      )`,

      // Messages table
      `CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        from_number TEXT NOT NULL,
        to_number TEXT NOT NULL,
        message_body TEXT,
        message_type TEXT NOT NULL DEFAULT 'text',
        status TEXT NOT NULL CHECK (status IN ('sent', 'delivered', 'read', 'failed')),
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        user_id TEXT,
        is_incoming BOOLEAN DEFAULT false,
        media_url TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      )`,

      // System metrics table
      `CREATE TABLE IF NOT EXISTS system_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        metric_type TEXT NOT NULL,
        metric_value REAL NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )`,

      // API logs table
      `CREATE TABLE IF NOT EXISTS api_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT NOT NULL,
        method TEXT NOT NULL,
        user_id TEXT,
        ip_address TEXT,
        user_agent TEXT,
        status_code INTEGER,
        response_time INTEGER,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
      )`
    ];

    for (const table of tables) {
      await this.run(table);
    }

    // Create indexes for better performance
    const indexes = [
      'CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages (session_id)',
      'CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages (timestamp)',
      'CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions (user_id)',
      'CREATE INDEX IF NOT EXISTS idx_api_logs_timestamp ON api_logs (timestamp)',
      'CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp ON system_metrics (timestamp)'
    ];

    for (const index of indexes) {
      await this.run(index);
    }
  }

  // Utility method to promisify database operations
  run(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.run(sql, params, function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ id: this.lastID, changes: this.changes });
        }
      });
    });
  }

  get(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.get(sql, params, (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row);
        }
      });
    });
  }

  all(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.all(sql, params, (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows);
        }
      });
    });
  }

  // User management methods
  async createUser(userData) {
    const id = uuidv4();
    const { username, password, role, status = 'active' } = userData;

    await this.run(
      'INSERT INTO users (id, username, password, role, status) VALUES (?, ?, ?, ?, ?)',
      [id, username, password, role, status]
    );

    return this.getUserById(id);
  }

  async getUserById(id) {
    const user = await this.get('SELECT * FROM users WHERE id = ?', [id]);
    if (user) {
      delete user.password; // Don't return password
    }
    return user;
  }

  async getUserByUsername(username) {
    return this.get('SELECT * FROM users WHERE username = ?', [username]);
  }

  async getAllUsers() {
    const users = await this.all('SELECT id, username, role, status, created_at, last_login FROM users ORDER BY created_at DESC');
    return users;
  }

  async updateUser(id, updates) {
    const fields = [];
    const values = [];

    Object.keys(updates).forEach(key => {
      if (key !== 'id') {
        fields.push(`${key} = ?`);
        values.push(updates[key]);
      }
    });

    fields.push('updated_at = CURRENT_TIMESTAMP');
    values.push(id);

    await this.run(
      `UPDATE users SET ${fields.join(', ')} WHERE id = ?`,
      values
    );

    return this.getUserById(id);
  }

  async deleteUser(id) {
    await this.run('DELETE FROM users WHERE id = ?', [id]);
  }

  async updateUserLastLogin(id) {
    await this.run('UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?', [id]);
  }

  // Session management methods
  async saveSession(sessionData) {
    const { id, name, status, phoneNumber, userId } = sessionData;
    
    await this.run(
      'INSERT OR REPLACE INTO sessions (id, name, status, phone_number, user_id, last_activity) VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
      [id, name, status, phoneNumber, userId]
    );
  }

  async updateSessionStatus(sessionId, status, phoneNumber = null) {
    await this.run(
      'UPDATE sessions SET status = ?, phone_number = ?, last_activity = CURRENT_TIMESTAMP WHERE id = ?',
      [status, phoneNumber, sessionId]
    );
  }

  async deleteSession(sessionId) {
    await this.run('DELETE FROM sessions WHERE id = ?', [sessionId]);
  }

  async getAllSessions() {
    return this.all('SELECT * FROM sessions ORDER BY created_at DESC');
  }

  // Message management methods
  async saveMessage(messageData) {
    const {
      id, sessionId, from, to, message, type, status, timestamp, userId, isIncoming = false, mediaUrl = null
    } = messageData;

    await this.run(
      'INSERT INTO messages (id, session_id, from_number, to_number, message_body, message_type, status, timestamp, user_id, is_incoming, media_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, sessionId, from, to, message, type, status, timestamp, userId, isIncoming, mediaUrl]
    );
  }

  async getMessages(sessionId = null, page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    let sql = 'SELECT * FROM messages';
    let params = [];

    if (sessionId) {
      sql += ' WHERE session_id = ?';
      params.push(sessionId);
    }

    sql += ' ORDER BY timestamp DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const messages = await this.all(sql, params);

    // Get total count
    let countSql = 'SELECT COUNT(*) as total FROM messages';
    let countParams = [];

    if (sessionId) {
      countSql += ' WHERE session_id = ?';
      countParams.push(sessionId);
    }

    const countResult = await this.get(countSql, countParams);

    return {
      messages,
      pagination: {
        page,
        limit,
        total: countResult.total,
        totalPages: Math.ceil(countResult.total / limit)
      }
    };
  }

  async getTotalMessageCount() {
    const result = await this.get('SELECT COUNT(*) as count FROM messages');
    return result.count;
  }

  async getMessagesMetrics() {
    // Get messages per hour for the last 24 hours
    const hourlyMessages = await this.all(`
      SELECT 
        strftime('%H', timestamp) as hour,
        COUNT(*) as count
      FROM messages 
      WHERE timestamp >= datetime('now', '-24 hours')
      GROUP BY strftime('%H', timestamp)
      ORDER BY hour
    `);

    // Get message types breakdown
    const messageTypes = await this.all(`
      SELECT 
        message_type,
        COUNT(*) as count
      FROM messages
      GROUP BY message_type
    `);

    // Get message status breakdown
    const messageStatus = await this.all(`
      SELECT 
        status,
        COUNT(*) as count
      FROM messages
      GROUP BY status
    `);

    return {
      hourlyMessages,
      messageTypes,
      messageStatus
    };
  }

  // System metrics methods
  async saveMetric(type, value) {
    await this.run(
      'INSERT INTO system_metrics (metric_type, metric_value) VALUES (?, ?)',
      [type, value]
    );
  }

  async getMetrics(type, hours = 24) {
    return this.all(`
      SELECT * FROM system_metrics 
      WHERE metric_type = ? AND timestamp >= datetime('now', '-${hours} hours')
      ORDER BY timestamp DESC
    `, [type]);
  }

  // API logging methods
  async logAPICall(logData) {
    const { endpoint, method, userId, ipAddress, userAgent, statusCode, responseTime } = logData;
    
    await this.run(
      'INSERT INTO api_logs (endpoint, method, user_id, ip_address, user_agent, status_code, response_time) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [endpoint, method, userId, ipAddress, userAgent, statusCode, responseTime]
    );
  }

  async getAPILogs(limit = 100) {
    return this.all(`
      SELECT al.*, u.username
      FROM api_logs al
      LEFT JOIN users u ON al.user_id = u.id
      ORDER BY al.timestamp DESC
      LIMIT ?
    `, [limit]);
  }

  // Cleanup methods
  async cleanupOldData(days = 30) {
    try {
      // Clean old system metrics
      await this.run(`
        DELETE FROM system_metrics 
        WHERE timestamp < datetime('now', '-${days} days')
      `);

      // Clean old API logs
      await this.run(`
        DELETE FROM api_logs 
        WHERE timestamp < datetime('now', '-${days} days')
      `);

      logger.info(`Cleaned up data older than ${days} days`);
    } catch (error) {
      logger.error('Error cleaning up old data:', error);
    }
  }

  async close() {
    if (this.db) {
      return new Promise((resolve) => {
        this.db.close((err) => {
          if (err) {
            logger.error('Error closing database:', err);
          } else {
            logger.info('Database connection closed');
          }
          resolve();
        });
      });
    }
  }

  // Backup methods
  async backup(backupPath) {
    try {
      await fs.copy(this.dbPath, backupPath);
      logger.info(`Database backed up to: ${backupPath}`);
    } catch (error) {
      logger.error('Database backup failed:', error);
      throw error;
    }
  }
}

module.exports = DatabaseManager;