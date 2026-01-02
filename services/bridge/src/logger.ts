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

// In production, redirect all console output through pino so third-party
// libraries (like SpacetimeDB SDK) don't break JSON log format
if (!isDev) {
  const sdkLogger = logger.child({ component: 'sdk' });
  
  console.log = (...args: unknown[]) => {
    sdkLogger.info({ raw: args.map(String).join(' ') }, 'console.log');
  };
  console.info = (...args: unknown[]) => {
    sdkLogger.info({ raw: args.map(String).join(' ') }, 'console.info');
  };
  console.warn = (...args: unknown[]) => {
    sdkLogger.warn({ raw: args.map(String).join(' ') }, 'console.warn');
  };
  console.error = (...args: unknown[]) => {
    sdkLogger.error({ raw: args.map(String).join(' ') }, 'console.error');
  };
  console.debug = (...args: unknown[]) => {
    sdkLogger.debug({ raw: args.map(String).join(' ') }, 'console.debug');
  };
}

