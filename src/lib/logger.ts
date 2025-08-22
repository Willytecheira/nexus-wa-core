// Production-safe logging utility
type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface Logger {
  debug: (message: string, ...args: any[]) => void;
  info: (message: string, ...args: any[]) => void;
  warn: (message: string, ...args: any[]) => void;
  error: (message: string, ...args: any[]) => void;
}

class ProductionLogger implements Logger {
  private isDevelopment = import.meta.env.DEV;
  
  private log(level: LogLevel, message: string, ...args: any[]) {
    if (!this.isDevelopment) {
      // In production, only log errors to console
      if (level === 'error') {
        console.error(`[ERROR] ${message}`, ...args);
      }
      return;
    }
    
    // In development, log everything with appropriate console method
    switch (level) {
      case 'debug':
        console.debug(`[DEBUG] ${message}`, ...args);
        break;
      case 'info':
        console.info(`[INFO] ${message}`, ...args);
        break;
      case 'warn':
        console.warn(`[WARN] ${message}`, ...args);
        break;
      case 'error':
        console.error(`[ERROR] ${message}`, ...args);
        break;
    }
  }
  
  debug(message: string, ...args: any[]) {
    this.log('debug', message, ...args);
  }
  
  info(message: string, ...args: any[]) {
    this.log('info', message, ...args);
  }
  
  warn(message: string, ...args: any[]) {
    this.log('warn', message, ...args);
  }
  
  error(message: string, ...args: any[]) {
    this.log('error', message, ...args);
  }
}

export const logger = new ProductionLogger();