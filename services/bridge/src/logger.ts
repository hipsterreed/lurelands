import pino from 'pino';

const isDev = process.env.NODE_ENV !== 'production';

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  transport: isDev
    ? {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'HH:MM:ss',
          ignore: 'pid,hostname',
        },
      }
    : undefined, // Use default JSON output in production (Railway)
  base: {
    service: 'lurelands-bridge',
  },
});

// Create child loggers for different components
export const wsLogger = logger.child({ component: 'ws' });
export const stdbLogger = logger.child({ component: 'stdb' });
export const serverLogger = logger.child({ component: 'server' });

