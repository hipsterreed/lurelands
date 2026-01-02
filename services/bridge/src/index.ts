import { Elysia } from 'elysia';
import { StdbClient } from './stdb-client';
import type { ClientMessage, ServerMessage, Player } from './types';

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
  for (const [ws, session] of clients) {
    try {
      ws.send(data);
    } catch (error) {
      // Client might be disconnected
    }
  }
}

function send(ws: any, message: ServerMessage) {
  try {
    ws.send(JSON.stringify(message));
  } catch (error) {
    console.error('[WS] Failed to send message:', error);
  }
}

// =============================================================================
// Message Handler
// =============================================================================

async function handleMessage(ws: any, session: ClientSession, message: ClientMessage) {
  console.log('[WS] Received message:', message.type, message);
  
  switch (message.type) {
    case 'join': {
      console.log('[WS] Player joining:', message.playerId, message.name);
      session.playerId = message.playerId;
      
      // Join the world via SpacetimeDB
      const spawnPos = await stdb.joinWorld(message.playerId, message.name, message.color);
      console.log('[WS] Spawn position:', spawnPos);
      
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

    default:
      console.warn('[WS] Unknown message type:', (message as any).type);
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
      console.log('[WS] Client connected, id:', wsId);
      clients.set(wsId, { ws, playerId: null });
      
      // Send initial state if available
      if (stdb.getIsConnected()) {
        send(ws, { type: 'world_state', data: stdb.getWorldState() });
      }
    },

    message(ws, rawMessage) {
      const wsId = getWsId(ws);
      console.log('[WS] Message from:', wsId, 'type:', typeof rawMessage);
      const session = clients.get(wsId);
      if (!session) {
        console.log('[WS] No session found for id:', wsId, 'available ids:', Array.from(clients.keys()));
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
        
        console.log('[WS] Message string:', messageStr.substring(0, 100));
        const message = JSON.parse(messageStr);
        handleMessage(ws, session, message as ClientMessage);
      } catch (error) {
        console.error('[WS] Failed to parse message:', error);
        send(ws, { type: 'error', message: 'Invalid message format' });
      }
    },

    close(ws) {
      const wsId = getWsId(ws);
      console.log('[WS] Client disconnected, id:', wsId);
      const session = clients.get(wsId);
      
      // Clean up player from world
      if (session?.playerId) {
        stdb.leaveWorld(session.playerId);
      }
      
      clients.delete(wsId);
    },
  })

  .listen({ port: PORT, hostname: HOST });

// =============================================================================
// Startup
// =============================================================================

async function main() {
  console.log('========================================');
  console.log('  Lurelands Bridge Service');
  console.log('========================================');
  console.log(`  Bridge:      http://${HOST}:${PORT}`);
  console.log(`  WebSocket:   ws://${HOST}:${PORT}/ws`);
  console.log(`  SpacetimeDB: ${SPACETIMEDB_URI}/${SPACETIMEDB_MODULE}`);
  console.log('========================================');
  
  // Connect to SpacetimeDB
  const connected = await stdb.connect();
  
  if (connected) {
    console.log('[STDB] Successfully connected to SpacetimeDB');
  } else {
    console.warn('[STDB] Failed to connect to SpacetimeDB - running in offline mode');
    console.warn('[STDB] Clients will receive empty world state');
  }
  
  console.log(`[Server] Listening on ${HOST}:${PORT}`);
}

main().catch(console.error);

export type App = typeof app;

