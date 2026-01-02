import { Elysia } from 'elysia';
import { StdbClient } from './stdb-client';
import type { ClientMessage, ServerMessage, Player } from './types';
import { logger, wsLogger, stdbLogger, serverLogger } from './logger';

// =============================================================================
// Configuration
// =============================================================================

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const HOST = process.env.HOST ?? '0.0.0.0';
const SPACETIMEDB_URI = process.env.SPACETIMEDB_URI ?? 'ws://localhost:3000';
const SPACETIMEDB_MODULE = process.env.SPACETIMEDB_MODULE ?? 'lurelands';

// =============================================================================
// Client Session Management
// =============================================================================

interface ClientSession {
  ws: any;
  playerId: string | null;
}

// Use ws.id as key instead of ws object (Elysia may use different wrapper objects)
const clients = new Map<string, ClientSession>();

function getWsId(ws: any): string {
  return ws.id ?? ws.raw?.id ?? String(ws);
}

// =============================================================================
// SpacetimeDB Client
// =============================================================================

const stdb = new StdbClient(SPACETIMEDB_URI, SPACETIMEDB_MODULE);

// Set up callbacks to broadcast to all connected clients
stdb.setCallbacks({
  onPlayersUpdate: (players: Player[]) => {
    broadcast({ type: 'players', players });
  },
  onWorldState: (worldState) => {
    broadcast({ type: 'world_state', data: worldState });
  },
  onFishCaught: (fishCatch) => {
    broadcast({ type: 'fish_caught', catch: fishCatch });
  },
});

// =============================================================================
// Broadcast Helper
// =============================================================================

function broadcast(message: ServerMessage) {
  const data = JSON.stringify(message);
  for (const [wsId, session] of clients) {
    try {
      session.ws.send(data);
    } catch (error) {
      // Client might be disconnected
    }
  }
}

function send(ws: any, message: ServerMessage) {
  try {
    ws.send(JSON.stringify(message));
  } catch (error) {
    wsLogger.error({ err: error, messageType: message.type }, 'Failed to send message');
  }
}

// =============================================================================
// Message Handler
// =============================================================================

async function handleMessage(ws: any, session: ClientSession, message: ClientMessage) {
  wsLogger.debug({ type: message.type, message }, 'Received message');
  
  switch (message.type) {
    case 'join': {
      wsLogger.info({ playerId: message.playerId, name: message.name }, 'Player joining');
      session.playerId = message.playerId;
      
      // Join the world via SpacetimeDB
      const spawnPos = await stdb.joinWorld(message.playerId, message.name, message.color);
      wsLogger.debug({ spawnPos }, 'Spawn position');
      
      if (spawnPos) {
        send(ws, { type: 'connected', playerId: message.playerId });
        send(ws, { type: 'spawn', x: spawnPos.x, y: spawnPos.y });
        send(ws, { type: 'world_state', data: stdb.getWorldState() });
        send(ws, { type: 'players', players: stdb.getPlayers() });
      } else {
        send(ws, { type: 'error', message: 'Failed to join world' });
      }
      break;
    }

    case 'move': {
      if (session.playerId) {
        await stdb.updatePosition(session.playerId, message.x, message.y, message.angle);
      }
      break;
    }

    case 'cast': {
      if (session.playerId) {
        await stdb.startCasting(session.playerId, message.targetX, message.targetY);
      }
      break;
    }

    case 'reel': {
      if (session.playerId) {
        await stdb.stopCasting(session.playerId);
      }
      break;
    }

    case 'leave': {
      if (session.playerId) {
        await stdb.leaveWorld(session.playerId);
        session.playerId = null;
      }
      break;
    }

    case 'update_name': {
      if (session.playerId) {
        await stdb.updatePlayerName(session.playerId, message.name);
      }
      break;
    }

    case 'fetch_player': {
      const player = stdb.getPlayer(message.playerId);
      send(ws, { type: 'player_data', player });
      break;
    }

    default:
      wsLogger.warn({ type: (message as any).type }, 'Unknown message type');
  }
}

// =============================================================================
// Elysia Server
// =============================================================================

const app = new Elysia()
  // Health check endpoint
  .get('/', () => ({
    status: 'ok',
    service: 'lurelands-bridge',
    spacetimedb: stdb.getIsConnected() ? 'connected' : 'disconnected',
    clients: clients.size,
  }))
  
  .get('/health', () => ({ status: 'ok' }))

  // WebSocket endpoint
  .ws('/ws', {
    open(ws) {
      const wsId = getWsId(ws);
      wsLogger.info({ wsId, clientCount: clients.size + 1 }, 'Client connected');
      clients.set(wsId, { ws, playerId: null });
      
      // Send initial state if available
      if (stdb.getIsConnected()) {
        send(ws, { type: 'world_state', data: stdb.getWorldState() });
      }
    },

    message(ws, rawMessage) {
      const wsId = getWsId(ws);
      wsLogger.debug({ wsId, rawType: typeof rawMessage }, 'Message received');
      const session = clients.get(wsId);
      if (!session) {
        wsLogger.warn({ wsId, availableIds: Array.from(clients.keys()) }, 'No session found');
        return;
      }
      // Update ws reference in case it changed
      session.ws = ws;

      try {
        // Handle different message formats (string, Buffer, object)
        let messageStr: string;
        if (typeof rawMessage === 'string') {
          messageStr = rawMessage;
        } else if (Buffer.isBuffer(rawMessage)) {
          messageStr = rawMessage.toString('utf-8');
        } else if (rawMessage instanceof Uint8Array) {
          messageStr = new TextDecoder().decode(rawMessage);
        } else {
          messageStr = JSON.stringify(rawMessage);
        }
        
        wsLogger.debug({ preview: messageStr.substring(0, 100) }, 'Parsing message');
        const message = JSON.parse(messageStr);
        handleMessage(ws, session, message as ClientMessage);
      } catch (error) {
        wsLogger.error({ err: error }, 'Failed to parse message');
        send(ws, { type: 'error', message: 'Invalid message format' });
      }
    },

    close(ws) {
      const wsId = getWsId(ws);
      wsLogger.info({ wsId, clientCount: clients.size - 1 }, 'Client disconnected');
      const session = clients.get(wsId);
      
      // Don't delete player from database on disconnect - they should persist
      // Players will remain in the database and can reconnect with the same data
      // Only call leaveWorld if the player explicitly sends a 'leave' message
      
      clients.delete(wsId);
    },
  })

  .listen({ port: PORT, hostname: HOST });

// =============================================================================
// Startup
// =============================================================================

async function main() {
  logger.info({
    bridge: `http://${HOST}:${PORT}`,
    websocket: `ws://${HOST}:${PORT}/ws`,
    spacetimedb: `${SPACETIMEDB_URI}/${SPACETIMEDB_MODULE}`,
  }, 'Lurelands Bridge Service starting');
  
  // Connect to SpacetimeDB
  const connected = await stdb.connect();
  
  if (connected) {
    stdbLogger.info('Successfully connected to SpacetimeDB');
  } else {
    stdbLogger.warn('Failed to connect to SpacetimeDB - running in offline mode');
  }
  
  serverLogger.info({ host: HOST, port: PORT }, 'Server listening');
}

main().catch((err) => {
  logger.fatal({ err }, 'Fatal error during startup');
  process.exit(1);
});

export type App = typeof app;

