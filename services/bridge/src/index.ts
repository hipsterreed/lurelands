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
  onInventoryUpdate: (playerId, items) => {
    // Send inventory update only to the player who owns it
    for (const [wsId, session] of clients) {
      if (session.playerId === playerId) {
        send(session.ws, { type: 'inventory', items });
      }
    }
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
        // Send player's inventory
        const inventory = stdb.getPlayerInventory(message.playerId);
        send(ws, { type: 'inventory', items: inventory });
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

    case 'catch_fish': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, itemId: message.itemId, rarity: message.rarity }, 'Player catching fish');
        await stdb.catchFish(session.playerId, message.itemId, message.rarity, message.waterBodyId);
        // Send updated inventory (the optimistic update in catchFish should have already updated the cache)
        const items = stdb.getPlayerInventory(session.playerId);
        send(ws, { type: 'inventory', items });
      }
      break;
    }

    case 'get_inventory': {
      if (session.playerId) {
        const items = stdb.getPlayerInventory(session.playerId);
        send(ws, { type: 'inventory', items });
      }
      break;
    }

    case 'sell_item': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, itemId: message.itemId, quantity: message.quantity }, 'Player selling item');
        await stdb.sellItem(session.playerId, message.itemId, message.rarity, message.quantity);
        // Send updated inventory
        const items = stdb.getPlayerInventory(session.playerId);
        send(ws, { type: 'inventory', items });
      }
      break;
    }

    case 'buy_item': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, itemId: message.itemId, price: message.price }, 'Player buying item');
        await stdb.buyItem(session.playerId, message.itemId, message.price);
        // Send updated inventory
        const items = stdb.getPlayerInventory(session.playerId);
        send(ws, { type: 'inventory', items });
      }
      break;
    }

    case 'equip_pole': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, poleItemId: message.poleItemId }, 'Player equipping pole');
        await stdb.equipPole(session.playerId, message.poleItemId);
      }
      break;
    }

    case 'unequip_pole': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId }, 'Player unequipping pole');
        await stdb.unequipPole(session.playerId);
      }
      break;
    }

    case 'set_gold': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, amount: message.amount }, 'Setting player gold (debug)');
        await stdb.setGold(session.playerId, message.amount);
      }
      break;
    }

    default:
      wsLogger.warn({ type: (message as any).type }, 'Unknown message type');
  }
}

// =============================================================================
// Events Page HTML
// =============================================================================

const eventsPageHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lurelands - Live Events</title>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #0a0e14;
      --bg-card: #151b24;
      --bg-hover: #1e2732;
      --text-primary: #e6edf3;
      --text-muted: #7d8590;
      --accent-blue: #58a6ff;
      --accent-green: #3fb950;
      --accent-yellow: #d29922;
      --accent-orange: #db6d28;
      --accent-purple: #a371f7;
      --accent-pink: #f778ba;
      --border-color: #30363d;
    }
    
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }
    
    body {
      font-family: 'Outfit', sans-serif;
      background: var(--bg-dark);
      color: var(--text-primary);
      min-height: 100vh;
      padding: 2rem;
    }
    
    .container {
      max-width: 1200px;
      margin: 0 auto;
    }
    
    header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 2rem;
      padding-bottom: 1.5rem;
      border-bottom: 1px solid var(--border-color);
    }
    
    h1 {
      font-size: 1.75rem;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }
    
    h1::before {
      content: '🎣';
      font-size: 1.5rem;
    }
    
    .status {
      display: flex;
      align-items: center;
      gap: 0.5rem;
      font-size: 0.875rem;
      color: var(--text-muted);
    }
    
    .status-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: var(--accent-green);
      animation: pulse 2s infinite;
    }
    
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    
    .stats-bar {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 1rem;
      margin-bottom: 2rem;
    }
    
    .stat-card {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      padding: 1.25rem;
    }
    
    .stat-label {
      font-size: 0.75rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 0.5rem;
    }
    
    .stat-value {
      font-size: 1.5rem;
      font-weight: 600;
      font-family: 'JetBrains Mono', monospace;
    }
    
    .events-container {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      overflow: hidden;
    }
    
    .events-header {
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--border-color);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .events-header h2 {
      font-size: 1rem;
      font-weight: 600;
    }
    
    .filter-pills {
      display: flex;
      gap: 0.5rem;
    }
    
    .filter-pill {
      padding: 0.375rem 0.75rem;
      border-radius: 999px;
      font-size: 0.75rem;
      border: 1px solid var(--border-color);
      background: transparent;
      color: var(--text-muted);
      cursor: pointer;
      transition: all 0.2s;
    }
    
    .filter-pill:hover, .filter-pill.active {
      background: var(--accent-blue);
      border-color: var(--accent-blue);
      color: white;
    }
    
    .events-list {
      max-height: 70vh;
      overflow-y: auto;
    }
    
    .event-row {
      display: grid;
      grid-template-columns: 140px 1fr 120px 100px;
      gap: 1rem;
      padding: 0.875rem 1.5rem;
      border-bottom: 1px solid var(--border-color);
      font-size: 0.875rem;
      transition: background 0.15s;
    }
    
    .event-row:hover {
      background: var(--bg-hover);
    }
    
    .event-row:last-child {
      border-bottom: none;
    }
    
    .event-time {
      font-family: 'JetBrains Mono', monospace;
      color: var(--text-muted);
      font-size: 0.8rem;
    }
    
    .event-type {
      font-weight: 500;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }
    
    .event-type-badge {
      padding: 0.25rem 0.5rem;
      border-radius: 6px;
      font-size: 0.75rem;
      font-weight: 600;
    }
    
    .type-fish_caught { background: rgba(63, 185, 80, 0.15); color: var(--accent-green); }
    .type-item_sold { background: rgba(210, 153, 34, 0.15); color: var(--accent-yellow); }
    .type-item_bought { background: rgba(88, 166, 255, 0.15); color: var(--accent-blue); }
    .type-session_started { background: rgba(163, 113, 247, 0.15); color: var(--accent-purple); }
    .type-session_ended { background: rgba(125, 133, 144, 0.15); color: var(--text-muted); }
    .type-pole_equipped { background: rgba(219, 109, 40, 0.15); color: var(--accent-orange); }
    .type-pole_unequipped { background: rgba(125, 133, 144, 0.15); color: var(--text-muted); }
    
    .event-player {
      color: var(--accent-blue);
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.8rem;
    }
    
    .event-details {
      color: var(--text-muted);
      font-size: 0.8rem;
    }
    
    .empty-state {
      padding: 4rem 2rem;
      text-align: center;
      color: var(--text-muted);
    }
    
    .empty-state-icon {
      font-size: 3rem;
      margin-bottom: 1rem;
    }
    
    @media (max-width: 768px) {
      .event-row {
        grid-template-columns: 1fr;
        gap: 0.5rem;
      }
      
      .stats-bar {
        grid-template-columns: 1fr 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Live Events</h1>
      <div class="status">
        <span class="status-dot"></span>
        <span id="status-text">Connecting...</span>
      </div>
    </header>
    
    <div class="stats-bar">
      <div class="stat-card">
        <div class="stat-label">Total Events</div>
        <div class="stat-value" id="stat-total">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Fish Caught</div>
        <div class="stat-value" id="stat-fish">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Items Sold</div>
        <div class="stat-value" id="stat-sold">-</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Items Bought</div>
        <div class="stat-value" id="stat-bought">-</div>
      </div>
    </div>
    
    <div class="events-container">
      <div class="events-header">
        <h2>Recent Events</h2>
        <div class="filter-pills">
          <button class="filter-pill active" data-filter="all">All</button>
          <button class="filter-pill" data-filter="fish_caught">🐟 Fish</button>
          <button class="filter-pill" data-filter="item_sold">💰 Sold</button>
          <button class="filter-pill" data-filter="item_bought">🛒 Bought</button>
          <button class="filter-pill" data-filter="session">👤 Sessions</button>
        </div>
      </div>
      <div class="events-list" id="events-list">
        <div class="empty-state">
          <div class="empty-state-icon">🎣</div>
          <p>Loading events...</p>
        </div>
      </div>
    </div>
  </div>
  
  <script>
    let events = [];
    let players = {}; // Map of playerId -> playerName
    let currentFilter = 'all';
    
    function formatTime(timestamp) {
      // Timestamps from SpacetimeDB are in microseconds
      const date = new Date(timestamp / 1000);
      return date.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit',
        hour12: false 
      });
    }
    
    function formatEventType(type) {
      const labels = {
        'fish_caught': '🐟 Fish Caught',
        'item_sold': '💰 Item Sold',
        'item_bought': '🛒 Item Bought',
        'session_started': '▶️ Session Started',
        'session_ended': '⏹️ Session Ended',
        'pole_equipped': '🎣 Pole Equipped',
        'pole_unequipped': '🎣 Pole Unequipped',
      };
      return labels[type] || type;
    }
    
    function getEventDetails(event) {
      const parts = [];
      if (event.itemId) parts.push(event.itemId);
      if (event.quantity) parts.push('x' + event.quantity);
      if (event.goldAmount) parts.push('💰 ' + event.goldAmount);
      if (event.rarity) {
        const stars = '⭐'.repeat(event.rarity);
        parts.push(stars);
      }
      if (event.waterBodyId) parts.push('@ ' + event.waterBodyId);
      return parts.join(' ');
    }
    
    function getPlayerName(playerId) {
      // Return player name if we have it, otherwise show shortened ID
      if (players[playerId]) {
        return players[playerId];
      }
      // Fallback to shortened ID
      if (playerId.length > 12) {
        return playerId.substring(0, 8) + '...';
      }
      return playerId;
    }
    
    function filterEvents(events, filter) {
      if (filter === 'all') return events;
      if (filter === 'session') {
        return events.filter(e => e.eventType === 'session_started' || e.eventType === 'session_ended');
      }
      return events.filter(e => e.eventType === filter);
    }
    
    function renderEvents() {
      const filtered = filterEvents(events, currentFilter);
      const container = document.getElementById('events-list');
      
      if (filtered.length === 0) {
        container.innerHTML = \`
          <div class="empty-state">
            <div class="empty-state-icon">🎣</div>
            <p>No events yet. Start playing to see events appear!</p>
          </div>
        \`;
        return;
      }
      
      container.innerHTML = filtered.map(event => \`
        <div class="event-row">
          <div class="event-time">\${formatTime(event.createdAt)}</div>
          <div class="event-type">
            <span class="event-type-badge type-\${event.eventType}">\${formatEventType(event.eventType)}</span>
          </div>
          <div class="event-player" title="\${event.playerId}">\${getPlayerName(event.playerId)}</div>
          <div class="event-details">\${getEventDetails(event)}</div>
        </div>
      \`).join('');
    }
    
    function updateStats() {
      document.getElementById('stat-total').textContent = events.length;
      document.getElementById('stat-fish').textContent = events.filter(e => e.eventType === 'fish_caught').length;
      document.getElementById('stat-sold').textContent = events.filter(e => e.eventType === 'item_sold').length;
      document.getElementById('stat-bought').textContent = events.filter(e => e.eventType === 'item_bought').length;
    }
    
    async function fetchData() {
      try {
        // Fetch events and players in parallel
        const [eventsRes, playersRes] = await Promise.all([
          fetch('/api/events?limit=100'),
          fetch('/api/players')
        ]);
        events = await eventsRes.json();
        players = await playersRes.json();
        document.getElementById('status-text').textContent = 'Connected • Auto-refresh';
        renderEvents();
        updateStats();
      } catch (error) {
        console.error('Failed to fetch data:', error);
        document.getElementById('status-text').textContent = 'Connection error';
      }
    }
    
    // Filter button handlers
    document.querySelectorAll('.filter-pill').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-pill').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentFilter = btn.dataset.filter;
        renderEvents();
      });
    });
    
    // Initial fetch
    fetchData();
    
    // Poll for updates every 3 seconds
    setInterval(fetchData, 3000);
  </script>
</body>
</html>`;

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

  // Events API endpoint
  .get('/api/events', ({ query }) => {
    const limit = parseInt(query.limit as string) || 50;
    return stdb.getGameEvents(limit);
  })

  // Players API endpoint (for name lookup)
  .get('/api/players', () => {
    const players = stdb.getPlayers();
    const playerMap: Record<string, string> = {};
    for (const p of players) {
      playerMap[p.id] = p.name;
    }
    return playerMap;
  })

  // Events viewer page
  .get('/events', () => {
    return new Response(eventsPageHtml, {
      headers: { 'Content-Type': 'text/html' },
    });
  })

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
      
      // Mark player as offline when they disconnect (but keep them in database)
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

