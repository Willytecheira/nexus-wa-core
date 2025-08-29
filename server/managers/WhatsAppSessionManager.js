const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');
const QRCode = require('qrcode');
const fs = require('fs-extra');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const logger = require('../utils/logger');

class WhatsAppSessionManager {
  constructor(io, dbManager = null) {
    this.io = io;
    this.sessions = new Map();
    this.qrCodes = new Map();
    this.db = dbManager;
  }

  setDatabaseManager(dbManager) {
    this.db = dbManager;
  }

  // Restore sessions from database on server startup
  async restoreSessionsFromDatabase() {
    if (!this.db) {
      logger.warn('No database manager available for session restoration');
      return;
    }

    try {
      logger.info('🔄 Starting session restoration from database...');
      const savedSessions = await this.db.getAllSessions();
      
      if (!savedSessions || savedSessions.length === 0) {
        logger.info('📭 No sessions found in database to restore');
        return;
      }

      logger.info(`📦 Found ${savedSessions.length} sessions to restore`);
      let restoredCount = 0;
      let failedCount = 0;

      for (const sessionData of savedSessions) {
        try {
          const { session_id, name, user_id, status } = sessionData;
          
          // Check if session files exist
          const sessionPath = path.join(__dirname, '..', 'sessions', session_id);
          if (!await fs.pathExists(sessionPath)) {
            logger.warn(`⚠️  Session files not found for ${name} (${session_id}), skipping...`);
            // Update status to disconnected in database
            await this.db.updateSessionStatus(session_id, 'disconnected');
            failedCount++;
            continue;
          }

          // Only restore if session was previously connected or ready
          if (status === 'connected' || status === 'ready' || status === 'authenticated') {
            logger.info(`🔧 Restoring session: ${name} (${session_id})`);
            
            // Create the WhatsApp client
            const client = new Client({
              authStrategy: new LocalAuth({
                clientId: session_id,
                dataPath: sessionPath
              }),
              puppeteer: {
                headless: true,
                args: [
                  '--no-sandbox',
                  '--disable-setuid-sandbox',
                  '--disable-dev-shm-usage',
                  '--disable-accelerated-2d-canvas',
                  '--no-first-run',
                  '--no-zygote',
                  '--single-process',
                  '--disable-gpu'
                ]
              }
            });

            const session = {
              id: session_id,
              name,
              userId: user_id,
              client,
              status: 'connecting',
              createdAt: new Date(),
              phoneNumber: null,
              isReady: false,
              messagesSent: 0,
              messagesReceived: 0,
              lastActivity: new Date()
            };

            // Setup event handlers
            await this.setupClientEvents(session);
            
            // Store session in memory
            this.sessions.set(session_id, session);
            
            // Initialize the client (this will attempt to restore the session)
            await client.initialize();
            
            // Update status to connecting in database
            await this.db.updateSessionStatus(session_id, 'connecting');
            
            restoredCount++;
            logger.info(`✅ Session ${name} queued for restoration`);
            
          } else {
            logger.info(`⏭️  Skipping session ${name} (${session_id}) - status: ${status}`);
            failedCount++;
          }
          
        } catch (sessionError) {
          logger.error(`❌ Failed to restore session ${sessionData.name}:`, sessionError);
          failedCount++;
          
          // Update status to disconnected in database
          if (sessionData.session_id) {
            await this.db.updateSessionStatus(sessionData.session_id, 'disconnected');
          }
        }
      }

      logger.info(`🎉 Session restoration completed: ${restoredCount} restored, ${failedCount} failed`);
      
      // Emit session list update
      this.io.emit('sessions:updated', this.getAllSessions());
      
    } catch (error) {
      logger.error('❌ Error during session restoration:', error);
    }
  }

  async createSession(name, userId) {
    const sessionId = uuidv4();
    const sessionPath = path.join(__dirname, '..', 'sessions', sessionId);

    try {
      // Ensure session directory exists
      await fs.ensureDir(sessionPath);

      const client = new Client({
        authStrategy: new LocalAuth({
          clientId: sessionId,
          dataPath: sessionPath
        }),
        puppeteer: {
          headless: true,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu'
          ]
        }
      });

      const session = {
        id: sessionId,
        name,
        client,
        status: 'initializing',
        qrCode: null,
        createdAt: new Date().toISOString(),
        userId,
        connected: false,
        phoneNumber: null,
        lastActivity: new Date().toISOString()
      };

      // Set up event listeners
      this.setupClientEvents(session);

      // Initialize the client
      await client.initialize();

      this.sessions.set(sessionId, session);

      // Save session to database
      if (this.db) {
        try {
          await this.db.saveSession({
            session_id: sessionId,
            name: name,
            user_id: userId,
            status: 'initializing',
            phone_number: null,
            created_at: session.createdAt,
            last_activity: session.lastActivity,
            uptime_start: session.createdAt
          });
          logger.info(`Session ${sessionId} saved to database`);
        } catch (error) {
          logger.error(`Failed to save session ${sessionId} to database:`, error);
        }
      }

      logger.info(`Session ${sessionId} (${name}) created successfully`);

      return {
        id: sessionId,
        name,
        status: 'initializing',
        createdAt: session.createdAt,
        connected: false
      };

    } catch (error) {
      logger.error(`Failed to create session ${sessionId}:`, error);
      throw new Error('Failed to create WhatsApp session');
    }
  }

  setupClientEvents(session) {
    const { client, id: sessionId } = session;

    client.on('qr', async (qr) => {
      try {
        // Generate QR code image
        const qrImagePath = path.join(__dirname, '..', 'qr', `${sessionId}.png`);
        await QRCode.toFile(qrImagePath, qr);

        // Generate base64 QR code for immediate display
        const qrBase64 = await QRCode.toDataURL(qr);
        console.log(`[${sessionId}] QR Code generated - Length: ${qrBase64.length}, Starts with: ${qrBase64.substring(0, 50)}...`);

        session.status = 'qr_received';
        session.qrCode = qrBase64;
        this.qrCodes.set(sessionId, qrBase64);

        // Emit to connected clients
        this.io.emit('session:qr', {
          sessionId,
          qrCode: qrBase64,
          status: 'qr_received'
        });
        console.log(`[${sessionId}] QR Code emitted to clients`);

        logger.info(`QR code generated for session ${sessionId}`);
      } catch (error) {
        logger.error(`QR code generation failed for session ${sessionId}:`, error);
      }
    });

    client.on('authenticated', async () => {
      session.status = 'authenticated';
      session.qrCode = null;
      this.qrCodes.delete(sessionId);

      // Update database
      if (this.db) {
        try {
          await this.db.updateSessionStatus(sessionId, 'authenticated', null);
        } catch (error) {
          logger.error(`Failed to update session ${sessionId} status in database:`, error);
        }
      }

      this.io.emit('session:status', {
        sessionId,
        status: 'authenticated'
      });

      logger.info(`Session ${sessionId} authenticated successfully`);
    });

    client.on('ready', async () => {
      session.status = 'ready';
      session.connected = true;
      session.phoneNumber = client.info?.wid?.user;
      session.lastActivity = new Date().toISOString();

      // Update database
      if (this.db) {
        try {
          await this.db.updateSessionStatus(sessionId, 'ready', session.phoneNumber);
          await this.db.updateSessionActivity(sessionId);
        } catch (error) {
          logger.error(`Failed to update session ${sessionId} in database:`, error);
        }
      }

      this.io.emit('session:status', {
        sessionId,
        status: 'ready',
        connected: true,
        phoneNumber: session.phoneNumber
      });

      logger.info(`Session ${sessionId} is ready`);
    });

    client.on('message', async (message) => {
      try {
        // Save incoming message
        const messageData = {
          id: message.id.id,
          sessionId,
          from: message.from,
          to: message.to,
          body: message.body,
          type: message.type,
          timestamp: new Date(message.timestamp * 1000).toISOString(),
          isForwarded: message.isForwarded,
          hasMedia: message.hasMedia
        };

        // Emit to connected clients
        this.io.emit('message:received', messageData);

        session.lastActivity = new Date().toISOString();

        logger.info(`Message received in session ${sessionId} from ${message.from}`);
      } catch (error) {
        logger.error(`Error processing incoming message for session ${sessionId}:`, error);
      }
    });

    client.on('disconnected', async (reason) => {
      session.status = 'disconnected';
      session.connected = false;

      // Update database
      if (this.db) {
        try {
          await this.db.updateSessionStatus(sessionId, 'disconnected', session.phoneNumber);
        } catch (error) {
          logger.error(`Failed to update session ${sessionId} status in database:`, error);
        }
      }

      this.io.emit('session:status', {
        sessionId,
        status: 'disconnected',
        connected: false,
        reason
      });

      logger.warn(`Session ${sessionId} disconnected: ${reason}`);
    });

    client.on('auth_failure', async (message) => {
      session.status = 'auth_failure';
      session.connected = false;

      // Update database
      if (this.db) {
        try {
          await this.db.updateSessionStatus(sessionId, 'auth_failure', session.phoneNumber);
          await this.db.incrementSessionErrors(sessionId);
        } catch (error) {
          logger.error(`Failed to update session ${sessionId} status in database:`, error);
        }
      }

      this.io.emit('session:status', {
        sessionId,
        status: 'auth_failure',
        connected: false,
        error: message
      });

      logger.error(`Authentication failed for session ${sessionId}: ${message}`);
    });
  }

  async destroySession(sessionId) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error('Session not found');
    }

    try {
      // Destroy the client
      if (session.client) {
        await session.client.destroy();
      }

      // Clean up files
      const sessionPath = path.join(__dirname, '..', 'sessions', sessionId);
      const qrPath = path.join(__dirname, '..', 'qr', `${sessionId}.png`);

      await fs.remove(sessionPath);
      await fs.remove(qrPath);

      // Remove from database
      if (this.db) {
        try {
          await this.db.deleteSession(sessionId);
        } catch (error) {
          logger.error(`Failed to delete session ${sessionId} from database:`, error);
        }
      }

      // Remove from memory
      this.sessions.delete(sessionId);
      this.qrCodes.delete(sessionId);

      // Emit to connected clients
      this.io.emit('session:destroyed', { sessionId });

      logger.info(`Session ${sessionId} destroyed successfully`);
    } catch (error) {
      logger.error(`Failed to destroy session ${sessionId}:`, error);
      throw new Error('Failed to destroy session');
    }
  }

  async restartSession(sessionId) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      throw new Error('Session not found');
    }

    try {
      // Destroy current client
      if (session.client) {
        await session.client.destroy();
      }

      // Reset session state
      session.status = 'initializing';
      session.connected = false;
      session.qrCode = null;
      session.phoneNumber = null;

      // Create new client
      const sessionPath = path.join(__dirname, '..', 'sessions', sessionId);
      const client = new Client({
        authStrategy: new LocalAuth({
          clientId: sessionId,
          dataPath: sessionPath
        }),
        puppeteer: {
          headless: true,
          args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-accelerated-2d-canvas',
            '--no-first-run',
            '--no-zygote',
            '--single-process',
            '--disable-gpu'
          ]
        }
      });

      session.client = client;
      this.setupClientEvents(session);

      // Initialize the new client
      await client.initialize();

      this.io.emit('session:status', {
        sessionId,
        status: 'initializing'
      });

      logger.info(`Session ${sessionId} restarted successfully`);
    } catch (error) {
      logger.error(`Failed to restart session ${sessionId}:`, error);
      throw new Error('Failed to restart session');
    }
  }

  async sendMessage(sessionId, to, message, type = 'text') {
    logger.info('=== SESSION MANAGER SEND MESSAGE DEBUG ===');
    logger.info('Parameters:', { sessionId, to, message, type });
    
    const session = this.sessions.get(sessionId);
    logger.info('Session lookup:', { 
      sessionId, 
      sessionExists: !!session,
      sessionStatus: session?.status,
      sessionConnected: session?.connected,
      clientExists: !!session?.client,
      totalSessions: this.sessions.size
    });
    
    if (!session) {
      logger.error('Session not found:', sessionId);
      logger.error('Available sessions:', Array.from(this.sessions.keys()));
      throw new Error('Session not found');
    }

    if (session.status !== 'ready' || !session.connected) {
      logger.error('Session not ready:', { 
        sessionId,
        status: session.status, 
        connected: session.connected,
        readyState: session.status === 'ready',
        bothReady: session.status === 'ready' && session.connected
      });
      throw new Error(`Session is not ready to send messages. Status: ${session.status}, Connected: ${session.connected}`);
    }

    if (!session.client) {
      logger.error('WhatsApp client not initialized for session:', sessionId);
      throw new Error('WhatsApp client not initialized');
    }

    try {
      logger.info('Sending message...');
      let result;

      // Format phone number
      const chatId = to.includes('@c.us') ? to : `${to}@c.us`;
      logger.info('Chat ID formatted:', { original: to, formatted: chatId });

      if (type === 'text') {
        logger.info('Sending text message via WhatsApp client...');
        result = await session.client.sendMessage(chatId, message);
        logger.info('WhatsApp client response:', { 
          success: !!result,
          messageId: result?.id?.id,
          ack: result?.ack,
          timestamp: result?.timestamp
        });
      } else if (type === 'media') {
        logger.info('Sending media message...');
        // Handle media messages
        const media = MessageMedia.fromFilePath(message);
        result = await session.client.sendMessage(chatId, media);
        logger.info('Media message sent:', { messageId: result?.id?.id });
      } else {
        logger.error('Unsupported message type:', type);
        throw new Error(`Unsupported message type: ${type}`);
      }

      session.lastActivity = new Date().toISOString();

      // Update message count if database is available
      if (this.db) {
        try {
          await this.db.incrementSessionMessageCount(sessionId, 'sent');
        } catch (dbError) {
          logger.error('Failed to update message count in database:', dbError);
        }
      }

      logger.info(`Message sent successfully from session ${sessionId} to ${to}`);
      logger.info('=== SESSION MANAGER SEND MESSAGE DEBUG END ===');

      return {
        success: true,
        messageId: result.id.id,
        timestamp: new Date().toISOString()
      };

    } catch (error) {
      logger.error('=== SESSION MANAGER SEND MESSAGE ERROR ===');
      logger.error(`Failed to send message from session ${sessionId}:`, error);
      logger.error('Error details:', {
        name: error.name,
        message: error.message,
        stack: error.stack,
        code: error.code
      });

      // Update error count if database is available
      if (this.db) {
        try {
          await this.db.incrementSessionErrors(sessionId);
        } catch (dbError) {
          logger.error('Failed to update error count in database:', dbError);
        }
      }

      logger.error('=== SESSION MANAGER SEND MESSAGE ERROR END ===');
      return {
        success: false,
        error: error.message,
        details: {
          name: error.name,
          code: error.code
        }
      };
    }
  }

  async getQRCode(sessionId) {
    return this.qrCodes.get(sessionId) || null;
  }

  getSession(sessionId) {
    return this.sessions.get(sessionId) || null;
  }

  async getAllSessions() {
    const sessions = Array.from(this.sessions.values()).map(session => ({
      id: session.id,
      name: session.name,
      status: session.status,
      connected: session.connected,
      phoneNumber: session.phoneNumber,
      createdAt: session.createdAt,
      lastActivity: session.lastActivity,
      userId: session.userId
    }));

    return sessions;
  }

  async getActiveSessionCount() {
    return Array.from(this.sessions.values()).filter(s => s.connected).length;
  }

  async getTotalSessionCount() {
    return this.sessions.size;
  }

  async getSessionsMetrics() {
    // If database is available, get metrics from database (persistent)
    if (this.db) {
      try {
        return await this.db.getSessionsMetrics();
      } catch (error) {
        logger.error('Failed to get sessions metrics from database:', error);
        // Fall back to memory-based metrics
      }
    }

    // Fallback: memory-based metrics
    const sessions = Array.from(this.sessions.values());
    const statusCounts = sessions.reduce((acc, session) => {
      acc[session.status] = (acc[session.status] || 0) + 1;
      return acc;
    }, {});

    return {
      total: sessions.length,
      active: sessions.filter(s => s.connected).length,
      statusBreakdown: statusCounts
    };
  }

  async destroyAllSessions() {
    const sessionIds = Array.from(this.sessions.keys());
    for (const sessionId of sessionIds) {
      try {
        await this.destroySession(sessionId);
      } catch (error) {
        logger.error(`Failed to destroy session ${sessionId} during shutdown:`, error);
      }
    }
  }

  // Webhook functionality
  async sendWebhook(sessionId, eventType, payload) {
    try {
      const dbManager = require('./DatabaseManager');
      const db = new dbManager();
      await db.initialize();

      // Get webhook URL from database
      const webhookConfig = await db.getSessionWebhook(sessionId);
      if (!webhookConfig || !webhookConfig.webhook_url) {
        return false;
      }

      const webhookPayload = {
        event: eventType,
        sessionId: sessionId,
        sessionName: webhookConfig.name,
        timestamp: new Date().toISOString(),
        data: payload
      };

      // Send webhook with retry logic
      const maxRetries = 3;
      let success = false;
      let lastError = null;

      for (let attempt = 0; attempt < maxRetries; attempt++) {
        try {
          const fetch = (await import('node-fetch')).default;
          const response = await fetch(webhookConfig.webhook_url, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'User-Agent': 'WhatsApp-API-Webhook/1.0'
            },
            body: JSON.stringify(webhookPayload),
            timeout: 10000
          });

          // Log webhook event
          await db.logWebhookEvent(
            sessionId,
            eventType,
            webhookConfig.webhook_url,
            webhookPayload,
            response.status,
            response.status < 400 ? 'success' : await response.text(),
            attempt
          );

          if (response.ok) {
            success = true;
            break;
          } else {
            lastError = `HTTP ${response.status}`;
          }
        } catch (error) {
          lastError = error.message;
          logger.warn(`Webhook attempt ${attempt + 1} failed for session ${sessionId}:`, error.message);
          
          // Log failed attempt
          await db.logWebhookEvent(
            sessionId,
            eventType,
            webhookConfig.webhook_url,
            webhookPayload,
            0,
            error.message,
            attempt
          );
        }

        // Wait before retry (exponential backoff)
        if (attempt < maxRetries - 1) {
          await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
        }
      }

      if (!success) {
        logger.error(`All webhook attempts failed for session ${sessionId}. Last error: ${lastError}`);
      }

      await db.close();
      return success;
    } catch (error) {
      logger.error(`Error sending webhook for session ${sessionId}:`, error);
      return false;
    }
  }
}

module.exports = WhatsAppSessionManager;