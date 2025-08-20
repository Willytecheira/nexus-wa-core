const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const fs = require('fs-extra');
const path = require('path');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
require('dotenv').config();

// Import custom modules
const WhatsAppSessionManager = require('./managers/WhatsAppSessionManager');
const DatabaseManager = require('./managers/DatabaseManager');
const AuthMiddleware = require('./middleware/auth');
const logger = require('./utils/logger');

// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: process.env.FRONTEND_URL || "http://localhost:5173",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your-super-secret-jwt-key';

// Initialize managers
const sessionManager = new WhatsAppSessionManager(io);
const db = new DatabaseManager();

// Security middleware
app.use(helmet({
  crossOriginEmbedderPolicy: false,
}));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.'
});
app.use('/api/', limiter);

// CORS configuration
const getAllowedOrigins = () => {
  const corsOrigins = process.env.CORS_ORIGINS || process.env.FRONTEND_URL || 'http://localhost:5173';
  return corsOrigins.split(',').map(origin => origin.trim());
};

const corsOptions = {
  origin: (origin, callback) => {
    const allowedOrigins = getAllowedOrigins();
    
    // Allow requests with no origin (mobile apps, curl, Postman, etc.)
    if (!origin) return callback(null, true);
    
    // Check if origin is in allowed list
    if (allowedOrigins.includes(origin)) {
      return callback(null, true);
    }
    
    // Allow localhost and 127.0.0.1 in development
    if (process.env.NODE_ENV !== 'production') {
      const localhostRegex = /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;
      if (localhostRegex.test(origin)) {
        return callback(null, true);
      }
    }
    
    logger.warn(`CORS blocked origin: ${origin}. Allowed origins: ${allowedOrigins.join(', ')}`);
    callback(new Error('Not allowed by CORS'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};

app.use(cors(corsOptions));

app.use(compression());
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) } }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Static files for QR codes and uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use('/qr', express.static(path.join(__dirname, 'qr')));

// Ensure directories exist
fs.ensureDirSync(path.join(__dirname, 'uploads'));
fs.ensureDirSync(path.join(__dirname, 'qr'));
fs.ensureDirSync(path.join(__dirname, 'logs'));
fs.ensureDirSync(path.join(__dirname, 'sessions'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    version: require('./package.json').version
  });
});

// Auth routes
app.post('/api/auth/login', async (req, res) => {
  try {
    const { username, password, rememberMe } = req.body;

    // Get user from database
    const user = await db.getUserByUsername(username);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check if user is active
    if (user.status !== 'active') {
      return res.status(401).json({ error: 'Account is disabled' });
    }

    // Generate JWT token
    const tokenExpiry = rememberMe ? '30d' : '24h';
    const token = jwt.sign(
      { userId: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: tokenExpiry }
    );

    // Update last login
    await db.updateUserLastLogin(user.id);

    // Return user data and token
    res.json({
      user: {
        id: user.id,
        username: user.username,
        role: user.role,
        lastLogin: new Date().toISOString(),
        status: user.status
      },
      token
    });

    logger.info(`User ${username} logged in successfully`);
  } catch (error) {
    logger.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

app.post('/api/auth/logout', AuthMiddleware, (req, res) => {
  logger.info(`User ${req.user.username} logged out`);
  res.json({ message: 'Logged out successfully' });
});

// Sessions routes
app.get('/api/sessions', AuthMiddleware, async (req, res) => {
  try {
    const sessions = await sessionManager.getAllSessions();
    res.json(sessions);
  } catch (error) {
    logger.error('Get sessions error:', error);
    res.status(500).json({ error: 'Failed to get sessions' });
  }
});

app.post('/api/sessions', AuthMiddleware, async (req, res) => {
  try {
    const { name } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'Session name is required' });
    }

    const session = await sessionManager.createSession(name, req.user.id);
    res.json(session);
    
    logger.info(`Session ${name} created by ${req.user.username}`);
  } catch (error) {
    logger.error('Create session error:', error);
    res.status(500).json({ error: 'Failed to create session' });
  }
});

app.delete('/api/sessions/:sessionId', AuthMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;
    await sessionManager.destroySession(sessionId);
    res.json({ message: 'Session deleted successfully' });
    
    logger.info(`Session ${sessionId} deleted by ${req.user.username}`);
  } catch (error) {
    logger.error('Delete session error:', error);
    res.status(500).json({ error: 'Failed to delete session' });
  }
});

app.post('/api/sessions/:sessionId/restart', AuthMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;
    await sessionManager.restartSession(sessionId);
    res.json({ message: 'Session restarted successfully' });
    
    logger.info(`Session ${sessionId} restarted by ${req.user.username}`);
  } catch (error) {
    logger.error('Restart session error:', error);
    res.status(500).json({ error: 'Failed to restart session' });
  }
});

app.get('/api/sessions/:sessionId/qr', AuthMiddleware, async (req, res) => {
  try {
    const { sessionId } = req.params;
    const qrCode = await sessionManager.getQRCode(sessionId);
    
    if (!qrCode) {
      return res.status(404).json({ error: 'QR code not available' });
    }

    res.json({ qrCode });
  } catch (error) {
    logger.error('Get QR code error:', error);
    res.status(500).json({ error: 'Failed to get QR code' });
  }
});

// Messages routes
app.get('/api/messages', AuthMiddleware, async (req, res) => {
  try {
    const { sessionId, page = 1, limit = 50 } = req.query;
    const messages = await db.getMessages(sessionId, parseInt(page), parseInt(limit));
    res.json(messages);
  } catch (error) {
    logger.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

app.post('/api/messages/send', AuthMiddleware, async (req, res) => {
  try {
    const { sessionId, to, message, type = 'text' } = req.body;

    if (!sessionId || !to || !message) {
      return res.status(400).json({ error: 'Session ID, recipient, and message are required' });
    }

    const result = await sessionManager.sendMessage(sessionId, to, message, type);
    
    // Save message to database
    await db.saveMessage({
      id: uuidv4(),
      sessionId,
      from: 'system',
      to,
      message,
      type,
      status: result.success ? 'sent' : 'failed',
      timestamp: new Date().toISOString(),
      userId: req.user.id
    });

    res.json(result);
    
    logger.info(`Message sent from session ${sessionId} to ${to} by ${req.user.username}`);
  } catch (error) {
    logger.error('Send message error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// Users routes (admin only)
app.get('/api/users', AuthMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const users = await db.getAllUsers();
    res.json(users);
  } catch (error) {
    logger.error('Get users error:', error);
    res.status(500).json({ error: 'Failed to get users' });
  }
});

app.post('/api/users', AuthMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { username, password, role } = req.body;
    
    if (!username || !password || !role) {
      return res.status(400).json({ error: 'Username, password, and role are required' });
    }

    // Check if user exists
    const existingUser = await db.getUserByUsername(username);
    if (existingUser) {
      return res.status(409).json({ error: 'Username already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = await db.createUser({
      username,
      password: hashedPassword,
      role,
      status: 'active'
    });

    res.json(user);
    
    logger.info(`User ${username} created by ${req.user.username}`);
  } catch (error) {
    logger.error('Create user error:', error);
    res.status(500).json({ error: 'Failed to create user' });
  }
});

app.put('/api/users/:userId', AuthMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { userId } = req.params;
    const updates = req.body;

    // Hash password if provided
    if (updates.password) {
      updates.password = await bcrypt.hash(updates.password, 10);
    }

    const user = await db.updateUser(userId, updates);
    res.json(user);
    
    logger.info(`User ${userId} updated by ${req.user.username}`);
  } catch (error) {
    logger.error('Update user error:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

app.delete('/api/users/:userId', AuthMiddleware, async (req, res) => {
  try {
    if (req.user.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const { userId } = req.params;
    
    // Prevent deleting self
    if (userId === req.user.userId) {
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }

    await db.deleteUser(userId);
    res.json({ message: 'User deleted successfully' });
    
    logger.info(`User ${userId} deleted by ${req.user.username}`);
  } catch (error) {
    logger.error('Delete user error:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// Metrics routes
app.get('/api/metrics', AuthMiddleware, async (req, res) => {
  try {
    const metrics = {
      systemStats: {
        activeSessions: await sessionManager.getActiveSessionCount(),
        totalMessages: await db.getTotalMessageCount(),
        memoryUsage: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
        cpuUsage: Math.round(process.cpuUsage().user / 1000),
        uptime: Math.floor(process.uptime())
      },
      sessionsData: await sessionManager.getSessionsMetrics(),
      messagesData: await db.getMessagesMetrics()
    };

    res.json(metrics);
  } catch (error) {
    logger.error('Get metrics error:', error);
    res.status(500).json({ error: 'Failed to get metrics' });
  }
});

// Socket.IO connection handling
io.on('connection', (socket) => {
  logger.info(`Client connected: ${socket.id}`);

  socket.on('join-session', (sessionId) => {
    socket.join(`session-${sessionId}`);
    logger.info(`Client ${socket.id} joined session ${sessionId}`);
  });

  socket.on('disconnect', () => {
    logger.info(`Client disconnected: ${socket.id}`);
  });
});

// Global error handler
app.use((error, req, res, next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ error: 'Route not found' });
});

// Initialize database and start server
async function startServer() {
  try {
    // Initialize database
    await db.initialize();
    
    // Create default admin user if it doesn't exist
    const adminExists = await db.getUserByUsername('admin');
    if (!adminExists) {
      const hashedPassword = await bcrypt.hash('admin123', 10);
      await db.createUser({
        username: 'admin',
        password: hashedPassword,
        role: 'admin',
        status: 'active'
      });
      logger.info('Default admin user created');
    }

    // Start server
    server.listen(PORT, () => {
      logger.info(`🚀 WhatsApp Multi-Session API Server running on port ${PORT}`);
      logger.info(`📊 Health check: http://localhost:${PORT}/health`);
      logger.info(`🔗 Environment: ${process.env.NODE_ENV || 'development'}`);
    });

    // Graceful shutdown handling
    process.on('SIGINT', gracefulShutdown);
    process.on('SIGTERM', gracefulShutdown);

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

async function gracefulShutdown() {
  logger.info('🛑 Graceful shutdown initiated...');
  
  try {
    // Close all WhatsApp sessions
    await sessionManager.destroyAllSessions();
    
    // Close database connection
    await db.close();
    
    // Close server
    server.close(() => {
      logger.info('✅ Server closed successfully');
      process.exit(0);
    });
  } catch (error) {
    logger.error('Error during shutdown:', error);
    process.exit(1);
  }
}

// Start the server
startServer();