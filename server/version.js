// WhatsApp Multi-Session API - Version Management
// Handles application versioning and update information

const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');

class VersionManager {
    constructor() {
        this.packagePath = path.join(__dirname, 'package.json');
        this.versionFile = path.join(__dirname, '..', '.version');
        this.projectRoot = path.join(__dirname, '..');
    }

    // Get current version from package.json
    getCurrentVersion() {
        try {
            const package = require(this.packagePath);
            return package.version;
        } catch (error) {
            return '0.0.0';
        }
    }

    // Get Git information
    getGitInfo() {
        try {
            const commit = execSync('git rev-parse HEAD', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).trim();
            
            const shortCommit = execSync('git rev-parse --short HEAD', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).trim();
            
            const branch = execSync('git rev-parse --abbrev-ref HEAD', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).trim();
            
            const lastCommitDate = execSync('git log -1 --format=%cd --date=iso', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).trim();
            
            const isDirty = execSync('git status --porcelain', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).trim().length > 0;
            
            return {
                commit,
                shortCommit,
                branch,
                lastCommitDate,
                isDirty
            };
        } catch (error) {
            return {
                commit: 'unknown',
                shortCommit: 'unknown',
                branch: 'unknown',
                lastCommitDate: 'unknown',
                isDirty: false
            };
        }
    }

    // Get build information
    getBuildInfo() {
        try {
            const stats = fs.statSync(this.packagePath);
            return {
                buildTime: new Date().toISOString(),
                nodeVersion: process.version,
                platform: process.platform,
                arch: process.arch,
                packageModified: stats.mtime.toISOString()
            };
        } catch (error) {
            return {
                buildTime: new Date().toISOString(),
                nodeVersion: process.version,
                platform: process.platform,
                arch: process.arch,
                packageModified: 'unknown'
            };
        }
    }

    // Generate complete version information
    getVersionInfo() {
        const version = this.getCurrentVersion();
        const git = this.getGitInfo();
        const build = this.getBuildInfo();
        
        return {
            version,
            git,
            build,
            api: {
                name: 'WhatsApp Multi-Session API',
                description: 'Enterprise WhatsApp API with multi-session support',
                author: 'WhatsApp API Team'
            }
        };
    }

    // Save version information to file
    async saveVersionInfo() {
        try {
            const versionInfo = this.getVersionInfo();
            await fs.writeJson(this.versionFile, versionInfo, { spaces: 2 });
            return versionInfo;
        } catch (error) {
            console.error('Failed to save version info:', error);
            return null;
        }
    }

    // Load version information from file
    async loadVersionInfo() {
        try {
            if (await fs.pathExists(this.versionFile)) {
                return await fs.readJson(this.versionFile);
            } else {
                return this.getVersionInfo();
            }
        } catch (error) {
            return this.getVersionInfo();
        }
    }

    // Compare versions
    compareVersions(version1, version2) {
        const v1parts = version1.split('.').map(Number);
        const v2parts = version2.split('.').map(Number);
        
        for (let i = 0; i < Math.max(v1parts.length, v2parts.length); i++) {
            const v1part = v1parts[i] || 0;
            const v2part = v2parts[i] || 0;
            
            if (v1part > v2part) return 1;
            if (v1part < v2part) return -1;
        }
        
        return 0;
    }

    // Check if update is available
    async checkForUpdates() {
        try {
            // Check remote version
            const remoteCommit = execSync('git ls-remote origin HEAD', { 
                cwd: this.projectRoot,
                encoding: 'utf8' 
            }).split('\t')[0];
            
            const currentCommit = this.getGitInfo().commit;
            
            return {
                updateAvailable: remoteCommit !== currentCommit,
                currentCommit: currentCommit.substring(0, 8),
                remoteCommit: remoteCommit.substring(0, 8)
            };
        } catch (error) {
            return {
                updateAvailable: false,
                error: error.message
            };
        }
    }

    // Generate version banner
    generateBanner() {
        const info = this.getVersionInfo();
        
        return `
╔══════════════════════════════════════════════════════════════╗
║                 WhatsApp Multi-Session API                  ║
║                                                              ║
║  Version: ${info.version.padEnd(10)} │ Commit: ${info.git.shortCommit.padEnd(10)}        ║
║  Branch:  ${info.git.branch.padEnd(10)} │ Node:   ${info.build.nodeVersion.padEnd(10)}        ║
║  Build:   ${info.build.buildTime.split('T')[0]} │ Platform: ${info.build.platform.padEnd(8)}      ║
║                                                              ║
║  🚀 Enterprise WhatsApp API with Multi-Session Support      ║
╚══════════════════════════════════════════════════════════════╝
        `.trim();
    }

    // Get system health information
    getSystemHealth() {
        try {
            const uptime = process.uptime();
            const memUsage = process.memoryUsage();
            
            return {
                uptime: Math.floor(uptime),
                memory: {
                    rss: Math.round(memUsage.rss / 1024 / 1024),
                    heapTotal: Math.round(memUsage.heapTotal / 1024 / 1024),
                    heapUsed: Math.round(memUsage.heapUsed / 1024 / 1024),
                    external: Math.round(memUsage.external / 1024 / 1024)
                },
                cpu: process.cpuUsage(),
                pid: process.pid,
                nodeVersion: process.version,
                platform: process.platform,
                arch: process.arch
            };
        } catch (error) {
            return { error: error.message };
        }
    }
}

// CLI functionality
async function main() {
    const args = process.argv.slice(2);
    const command = args[0] || 'info';
    
    const versionManager = new VersionManager();
    
    switch (command) {
        case 'info':
            const info = versionManager.getVersionInfo();
            console.log(JSON.stringify(info, null, 2));
            break;
            
        case 'banner':
            console.log(versionManager.generateBanner());
            break;
            
        case 'version':
            console.log(versionManager.getCurrentVersion());
            break;
            
        case 'commit':
            console.log(versionManager.getGitInfo().shortCommit);
            break;
            
        case 'save':
            const saved = await versionManager.saveVersionInfo();
            if (saved) {
                console.log('Version information saved');
            } else {
                console.log('Failed to save version information');
                process.exit(1);
            }
            break;
            
        case 'check':
            const updateCheck = await versionManager.checkForUpdates();
            console.log(JSON.stringify(updateCheck, null, 2));
            break;
            
        case 'health':
            const health = versionManager.getSystemHealth();
            console.log(JSON.stringify(health, null, 2));
            break;
            
        default:
            console.log('Usage: node version.js [command]');
            console.log('Commands:');
            console.log('  info     - Show complete version information');
            console.log('  banner   - Show version banner');
            console.log('  version  - Show version number only');
            console.log('  commit   - Show git commit hash');
            console.log('  save     - Save version info to file');
            console.log('  check    - Check for updates');
            console.log('  health   - Show system health');
    }
}

// Auto-save version info when required as module
if (require.main !== module) {
    const versionManager = new VersionManager();
    versionManager.saveVersionInfo().catch(() => {
        // Ignore errors when used as module
    });
}

// Run if called directly
if (require.main === module) {
    main().catch(error => {
        console.error('Version command failed:', error);
        process.exit(1);
    });
}

module.exports = VersionManager;