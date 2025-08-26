#!/usr/bin/env node

// WhatsApp Multi-Session API - Database Migration System
// Handles schema updates and data migrations

const fs = require('fs-extra');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();
const logger = require('../utils/logger');

class MigrationManager {
    constructor() {
        this.dbPath = path.join(__dirname, '..', 'database', 'whatsapp_api.db');
        this.migrationsPath = __dirname;
        this.db = null;
    }

    async init() {
        try {
            // Ensure database directory exists
            await fs.ensureDir(path.dirname(this.dbPath));
            
            // Open database connection
            this.db = new sqlite3.Database(this.dbPath);
            
            // Create migrations table if it doesn't exist
            await this.createMigrationsTable();
            
            logger.info('Migration manager initialized');
        } catch (error) {
            logger.error('Failed to initialize migration manager:', error);
            throw error;
        }
    }

    async createMigrationsTable() {
        return new Promise((resolve, reject) => {
            const sql = `
                CREATE TABLE IF NOT EXISTS migrations (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    version VARCHAR(255) NOT NULL UNIQUE,
                    filename VARCHAR(255) NOT NULL,
                    executed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                    execution_time INTEGER
                )
            `;
            
            this.db.run(sql, (err) => {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
    }

    async getExecutedMigrations() {
        return new Promise((resolve, reject) => {
            const sql = 'SELECT version FROM migrations ORDER BY version';
            
            this.db.all(sql, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows.map(row => row.version));
                }
            });
        });
    }

    async recordMigration(version, filename, executionTime) {
        return new Promise((resolve, reject) => {
            const sql = `
                INSERT INTO migrations (version, filename, execution_time)
                VALUES (?, ?, ?)
            `;
            
            this.db.run(sql, [version, filename, executionTime], (err) => {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
    }

    async getPendingMigrations() {
        try {
            const migrationFiles = await fs.readdir(this.migrationsPath);
            const executedMigrations = await this.getExecutedMigrations();
            
            const pending = migrationFiles
                .filter(file => file.endsWith('.sql') && file !== 'migrate.js' && !file.includes('_rollback'))
                .map(file => {
                    const version = file.replace('.sql', '');
                    return { version, filename: file };
                })
                .filter(migration => !executedMigrations.includes(migration.version))
                .sort((a, b) => a.version.localeCompare(b.version));
            
            return pending;
        } catch (error) {
            logger.error('Failed to get pending migrations:', error);
            return [];
        }
    }

    async executeMigration(migration) {
        const startTime = Date.now();
        
        try {
            const migrationPath = path.join(this.migrationsPath, migration.filename);
            const sql = await fs.readFile(migrationPath, 'utf8');
            
            // Split SQL into individual statements
            const statements = sql
                .split(';')
                .map(stmt => stmt.trim())
                .filter(stmt => stmt.length > 0);
            
            // Execute each statement
            for (const statement of statements) {
                await this.executeStatement(statement);
            }
            
            const executionTime = Date.now() - startTime;
            
            // Record successful migration
            await this.recordMigration(migration.version, migration.filename, executionTime);
            
            logger.info(`Migration ${migration.version} executed successfully in ${executionTime}ms`);
            
        } catch (error) {
            logger.error(`Failed to execute migration ${migration.version}:`, error);
            throw error;
        }
    }

    async executeStatement(statement) {
        return new Promise((resolve, reject) => {
            this.db.run(statement, (err) => {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
    }

    async runMigrations() {
        try {
            const pendingMigrations = await this.getPendingMigrations();
            
            if (pendingMigrations.length === 0) {
                logger.info('No pending migrations');
                return;
            }
            
            logger.info(`Found ${pendingMigrations.length} pending migrations`);
            
            for (const migration of pendingMigrations) {
                logger.info(`Executing migration: ${migration.version}`);
                await this.executeMigration(migration);
            }
            
            logger.info('All migrations completed successfully');
            
        } catch (error) {
            logger.error('Migration failed:', error);
            throw error;
        }
    }

    async rollback(targetVersion) {
        try {
            const executedMigrations = await this.getExecutedMigrations();
            const migrationsToRollback = executedMigrations
                .filter(version => version > targetVersion)
                .sort((a, b) => b.localeCompare(a)); // Reverse order
            
            if (migrationsToRollback.length === 0) {
                logger.info('No migrations to rollback');
                return;
            }
            
            logger.info(`Rolling back ${migrationsToRollback.length} migrations`);
            
            for (const version of migrationsToRollback) {
                const rollbackFile = path.join(this.migrationsPath, `${version}_rollback.sql`);
                
                if (await fs.pathExists(rollbackFile)) {
                    logger.info(`Rolling back migration: ${version}`);
                    
                    const sql = await fs.readFile(rollbackFile, 'utf8');
                    const statements = sql
                        .split(';')
                        .map(stmt => stmt.trim())
                        .filter(stmt => stmt.length > 0);
                    
                    for (const statement of statements) {
                        await this.executeStatement(statement);
                    }
                    
                    // Remove migration record
                    await this.removeMigrationRecord(version);
                    
                    logger.info(`Migration ${version} rolled back successfully`);
                } else {
                    logger.warn(`No rollback file found for migration: ${version}`);
                }
            }
            
        } catch (error) {
            logger.error('Rollback failed:', error);
            throw error;
        }
    }

    async removeMigrationRecord(version) {
        return new Promise((resolve, reject) => {
            const sql = 'DELETE FROM migrations WHERE version = ?';
            
            this.db.run(sql, [version], (err) => {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
    }

    async getMigrationStatus() {
        try {
            const executedMigrations = await this.getExecutedMigrations();
            const pendingMigrations = await this.getPendingMigrations();
            
            return {
                executed: executedMigrations,
                pending: pendingMigrations.map(m => m.version),
                total: executedMigrations.length + pendingMigrations.length
            };
        } catch (error) {
            logger.error('Failed to get migration status:', error);
            return { executed: [], pending: [], total: 0 };
        }
    }

    async close() {
        if (this.db) {
            this.db.close();
        }
    }
}

// CLI functionality
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'migrate';
    
    const migrationManager = new MigrationManager();
    
    try {
        await migrationManager.init();
        
        switch (command) {
            case 'migrate':
                await migrationManager.runMigrations();
                break;
                
            case 'rollback':
                const targetVersion = args[1];
                if (!targetVersion) {
                    console.error('Please specify target version for rollback');
                    process.exit(1);
                }
                await migrationManager.rollback(targetVersion);
                break;
                
            case 'status':
                const status = await migrationManager.getMigrationStatus();
                console.log('Migration Status:');
                console.log(`  Executed: ${status.executed.length}`);
                console.log(`  Pending: ${status.pending.length}`);
                console.log(`  Total: ${status.total}`);
                
                if (status.executed.length > 0) {
                    console.log('\nExecuted migrations:');
                    status.executed.forEach(version => console.log(`  - ${version}`));
                }
                
                if (status.pending.length > 0) {
                    console.log('\nPending migrations:');
                    status.pending.forEach(version => console.log(`  - ${version}`));
                }
                break;
                
            case 'create':
                const migrationName = args[1];
                if (!migrationName) {
                    console.error('Please specify migration name');
                    process.exit(1);
                }
                
                const timestamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
                const version = `${timestamp}_${migrationName}`;
                const filename = `${version}.sql`;
                const filepath = path.join(__dirname, filename);
                
                const template = `-- Migration: ${migrationName}
-- Created: ${new Date().toISOString()}
-- Version: ${version}

-- Add your migration SQL here
-- Example:
-- CREATE TABLE example (
--     id INTEGER PRIMARY KEY AUTOINCREMENT,
--     name VARCHAR(255) NOT NULL,
--     created_at DATETIME DEFAULT CURRENT_TIMESTAMP
-- );

-- ALTER TABLE existing_table ADD COLUMN new_column VARCHAR(255);
`;
                
                await fs.writeFile(filepath, template);
                console.log(`Created migration: ${filename}`);
                
                // Create rollback template
                const rollbackFilename = `${version}_rollback.sql`;
                const rollbackFilepath = path.join(__dirname, rollbackFilename);
                const rollbackTemplate = `-- Rollback for: ${migrationName}
-- Version: ${version}

-- Add rollback SQL here
-- Example:
-- DROP TABLE example;
-- ALTER TABLE existing_table DROP COLUMN new_column;
`;
                
                await fs.writeFile(rollbackFilepath, rollbackTemplate);
                console.log(`Created rollback: ${rollbackFilename}`);
                break;
                
            default:
                console.log('Usage: node migrate.js [command] [args]');
                console.log('Commands:');
                console.log('  migrate          - Run pending migrations');
                console.log('  rollback <ver>   - Rollback to specific version');
                console.log('  status           - Show migration status');
                console.log('  create <name>    - Create new migration');
        }
        
    } catch (error) {
        logger.error('Migration command failed:', error);
        process.exit(1);
    } finally {
        await migrationManager.close();
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = MigrationManager;