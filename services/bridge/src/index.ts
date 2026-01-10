import { Elysia } from 'elysia';
import { StdbClient } from './stdb-client';
import type { ClientMessage, ServerMessage, Player } from './types';
import { logger, wsLogger, stdbLogger, serverLogger } from './logger';
import { createInflate, createGunzip } from 'zlib';
import { Readable } from 'stream';

// Polyfill DecompressionStream for Bun compatibility
if (typeof globalThis.DecompressionStream === 'undefined') {
  (globalThis as any).DecompressionStream = class DecompressionStream {
    readable: ReadableStream;
    writable: WritableStream;

    constructor(format: 'gzip' | 'deflate' | 'deflate-raw') {
      const decompressor = format === 'gzip' ? createGunzip() : createInflate();

      this.readable = new ReadableStream({
        start(controller) {
          decompressor.on('data', (chunk) => controller.enqueue(chunk));
          decompressor.on('end', () => controller.close());
          decompressor.on('error', (err) => controller.error(err));
        }
      });

      this.writable = new WritableStream({
        write(chunk) {
          decompressor.write(chunk);
        },
        close() {
          decompressor.end();
        }
      });
    }
  };
}

// =============================================================================
// Configuration
// =============================================================================

const PORT = parseInt(process.env.PORT ?? '8080', 10);
const HOST = process.env.HOST ?? '0.0.0.0';
const SPACETIMEDB_URI = process.env.SPACETIMEDB_URI ?? 'ws://localhost:3000';
const SPACETIMEDB_MODULE = process.env.SPACETIMEDB_MODULE ?? 'lurelands';
const SERVICE_KEY = process.env.SERVICE_KEY ?? '';

// Service key validation helper
function validateServiceKey(request: Request): Response | null {
  if (!SERVICE_KEY) return null; // No key configured = no auth required
  const providedKey = request.headers.get('X-Service-Key');
  if (providedKey !== SERVICE_KEY) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  return null;
}

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
  onQuestUpdate: (playerId, quests, playerQuests) => {
    // Send quest update only to the player who owns it
    for (const [wsId, session] of clients) {
      if (session.playerId === playerId) {
        send(session.ws, { type: 'quests', quests, playerQuests });
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
        // Send player's quests
        const quests = stdb.getQuests();
        const playerQuests = stdb.getPlayerQuests(message.playerId);
        send(ws, { type: 'quests', quests, playerQuests });
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

    // Quest handlers
    case 'get_quests': {
      if (session.playerId) {
        const quests = stdb.getQuests();
        const playerQuests = stdb.getPlayerQuests(session.playerId);
        send(ws, { type: 'quests', quests, playerQuests });
      }
      break;
    }

    case 'accept_quest': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, questId: message.questId }, 'Player accepting quest');
        await stdb.acceptQuest(session.playerId, message.questId);
        // Send updated quests
        const quests = stdb.getQuests();
        const playerQuests = stdb.getPlayerQuests(session.playerId);
        send(ws, { type: 'quests', quests, playerQuests });
      }
      break;
    }

    case 'complete_quest': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId, questId: message.questId }, 'Player completing quest');
        await stdb.completeQuest(session.playerId, message.questId);
        // Send updated quests and inventory (rewards may have been granted)
        const quests = stdb.getQuests();
        const playerQuests = stdb.getPlayerQuests(session.playerId);
        send(ws, { type: 'quests', quests, playerQuests });
        const items = stdb.getPlayerInventory(session.playerId);
        send(ws, { type: 'inventory', items });
      }
      break;
    }

    case 'reset_quests': {
      if (session.playerId) {
        wsLogger.info({ playerId: session.playerId }, 'Player resetting all quests');
        await stdb.resetPlayerQuests(session.playerId);
        // Send updated quests (should now be empty for this player)
        const quests = stdb.getQuests();
        const playerQuests = stdb.getPlayerQuests(session.playerId);
        send(ws, { type: 'quests', quests, playerQuests });
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
// Quest Admin Page HTML
// =============================================================================

const questAdminPageHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lurelands - Quest Admin</title>
  <link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;500;700&family=Outfit:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg-dark: #0a0e14;
      --bg-card: #151b24;
      --bg-hover: #1e2732;
      --bg-input: #0d1117;
      --text-primary: #e6edf3;
      --text-muted: #7d8590;
      --accent-blue: #58a6ff;
      --accent-green: #3fb950;
      --accent-yellow: #d29922;
      --accent-orange: #db6d28;
      --accent-purple: #a371f7;
      --accent-red: #f85149;
      --border-color: #30363d;
    }
    
    * { box-sizing: border-box; margin: 0; padding: 0; }
    
    body {
      font-family: 'Outfit', sans-serif;
      background: var(--bg-dark);
      color: var(--text-primary);
      min-height: 100vh;
      padding: 2rem;
    }
    
    .container { max-width: 1400px; margin: 0 auto; }
    
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
    
    h1::before { content: '📜'; font-size: 1.5rem; }
    
    .nav-links {
      display: flex;
      gap: 1rem;
    }
    
    .nav-link {
      color: var(--text-muted);
      text-decoration: none;
      padding: 0.5rem 1rem;
      border-radius: 8px;
      transition: all 0.2s;
    }
    
    .nav-link:hover {
      background: var(--bg-card);
      color: var(--text-primary);
    }
    
    .layout {
      display: grid;
      grid-template-columns: 400px 1fr;
      gap: 2rem;
    }
    
    @media (max-width: 1000px) {
      .layout { grid-template-columns: 1fr; }
    }
    
    .panel {
      background: var(--bg-card);
      border: 1px solid var(--border-color);
      border-radius: 12px;
      overflow: hidden;
    }
    
    .panel-header {
      padding: 1rem 1.5rem;
      border-bottom: 1px solid var(--border-color);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    
    .panel-header h2 {
      font-size: 1rem;
      font-weight: 600;
    }
    
    .panel-content {
      padding: 1.5rem;
      max-height: calc(100vh - 200px);
      overflow-y: auto;
    }
    
    .quest-list { display: flex; flex-direction: column; gap: 0.5rem; }
    
    .storyline-group {
      margin-bottom: 1.5rem;
    }
    
    .storyline-header {
      font-size: 0.75rem;
      color: var(--accent-purple);
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 0.5rem;
      padding-left: 0.5rem;
    }
    
    .quest-item {
      padding: 0.75rem 1rem;
      background: var(--bg-hover);
      border-radius: 8px;
      cursor: pointer;
      transition: all 0.15s;
      border: 2px solid transparent;
    }
    
    .quest-item:hover { border-color: var(--border-color); }
    .quest-item.selected { border-color: var(--accent-blue); background: rgba(88, 166, 255, 0.1); }
    
    .quest-item-title {
      font-weight: 500;
      margin-bottom: 0.25rem;
    }
    
    .quest-item-meta {
      font-size: 0.75rem;
      color: var(--text-muted);
      display: flex;
      gap: 0.75rem;
    }
    
    .badge {
      padding: 0.125rem 0.5rem;
      border-radius: 999px;
      font-size: 0.7rem;
      font-weight: 600;
    }
    
    .badge-story { background: rgba(163, 113, 247, 0.2); color: var(--accent-purple); }
    .badge-daily { background: rgba(210, 153, 34, 0.2); color: var(--accent-yellow); }
    
    .form-group {
      margin-bottom: 1.25rem;
    }
    
    label {
      display: block;
      font-size: 0.875rem;
      color: var(--text-muted);
      margin-bottom: 0.5rem;
    }
    
    input, textarea, select {
      width: 100%;
      padding: 0.75rem 1rem;
      background: var(--bg-input);
      border: 1px solid var(--border-color);
      border-radius: 8px;
      color: var(--text-primary);
      font-family: inherit;
      font-size: 0.875rem;
    }
    
    input:focus, textarea:focus, select:focus {
      outline: none;
      border-color: var(--accent-blue);
    }
    
    textarea {
      min-height: 80px;
      resize: vertical;
    }
    
    .form-row {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
    }
    
    .btn {
      padding: 0.75rem 1.5rem;
      border: none;
      border-radius: 8px;
      font-family: inherit;
      font-size: 0.875rem;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
    }
    
    .btn-primary {
      background: var(--accent-blue);
      color: white;
    }
    
    .btn-primary:hover { background: #4393e6; }
    
    .btn-success {
      background: var(--accent-green);
      color: white;
    }
    
    .btn-success:hover { background: #36a146; }
    
    .btn-danger {
      background: var(--accent-red);
      color: white;
    }
    
    .btn-danger:hover { background: #e04040; }
    
    .btn-secondary {
      background: var(--bg-hover);
      color: var(--text-primary);
      border: 1px solid var(--border-color);
    }
    
    .btn-secondary:hover { background: var(--border-color); }
    
    .btn-group {
      display: flex;
      gap: 0.75rem;
      margin-top: 1.5rem;
    }
    
    .json-editor {
      font-family: 'JetBrains Mono', monospace;
      font-size: 0.8rem;
    }
    
    .help-text {
      font-size: 0.75rem;
      color: var(--text-muted);
      margin-top: 0.25rem;
    }
    
    .toast {
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      padding: 1rem 1.5rem;
      border-radius: 8px;
      color: white;
      font-weight: 500;
      z-index: 1000;
      animation: slideIn 0.3s ease;
    }
    
    .toast-success { background: var(--accent-green); }
    .toast-error { background: var(--accent-red); }
    
    @keyframes slideIn {
      from { transform: translateX(100%); opacity: 0; }
      to { transform: translateX(0); opacity: 1; }
    }
    
    .empty-state {
      text-align: center;
      padding: 3rem;
      color: var(--text-muted);
    }
    
    .section-title {
      font-size: 0.75rem;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.1em;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--border-color);
    }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>Quest Admin</h1>
      <div class="nav-links">
        <a href="/" class="nav-link">Status</a>
        <a href="/events" class="nav-link">Events</a>
        <a href="/admin/quests" class="nav-link" style="background: var(--bg-card); color: var(--accent-blue);">Quests</a>
      </div>
    </header>
    
    <div class="layout">
      <!-- Quest List Panel -->
      <div class="panel">
        <div class="panel-header">
          <h2>Quests</h2>
          <div style="display: flex; gap: 0.5rem;">
            <button class="btn btn-secondary" onclick="seedQuests()">Seed Defaults</button>
            <button class="btn btn-primary" onclick="newQuest()">+ New Quest</button>
          </div>
        </div>
        <div class="panel-content">
          <div id="quest-list" class="quest-list">
            <div class="empty-state">Loading quests...</div>
          </div>
        </div>
      </div>
      
      <!-- Quest Editor Panel -->
      <div class="panel">
        <div class="panel-header">
          <h2 id="editor-title">Quest Editor</h2>
          <span id="editor-mode" class="badge badge-story"></span>
        </div>
        <div class="panel-content">
          <form id="quest-form" onsubmit="saveQuest(event)">
            <div class="form-row">
              <div class="form-group">
                <label>Quest ID</label>
                <input type="text" id="quest-id" required placeholder="e.g., guild_4">
                <div class="help-text">Unique identifier (lowercase, underscores)</div>
              </div>
              <div class="form-group">
                <label>Quest Type</label>
                <select id="quest-type" onchange="updateTypeFields()">
                  <option value="story">Story Quest</option>
                  <option value="daily">Daily Quest</option>
                </select>
              </div>
            </div>
            
            <div class="form-group">
              <label>Title</label>
              <input type="text" id="quest-title" required placeholder="Quest display name">
            </div>
            
            <div class="form-group">
              <label>Description</label>
              <textarea id="quest-description" required placeholder="Flavor text shown to players..."></textarea>
            </div>
            
            <div id="story-fields">
              <div class="form-row">
                <div class="form-group">
                  <label>Storyline</label>
                  <input type="text" id="quest-storyline" placeholder="e.g., fishermans_guild">
                </div>
                <div class="form-group">
                  <label>Order in Storyline</label>
                  <input type="number" id="quest-order" min="1" placeholder="1, 2, 3...">
                </div>
              </div>
              
              <div class="form-group">
                <label>Prerequisite Quest ID</label>
                <input type="text" id="quest-prereq" placeholder="Quest that must be completed first">
              </div>
            </div>
            
            <div class="section-title">Requirements</div>
            
            <div class="form-group">
              <label>Requirements (JSON)</label>
              <textarea id="quest-requirements" class="json-editor" placeholder='{"total_fish": 5}'></textarea>
              <div class="help-text">
                Examples: {"total_fish": 5}, {"fish": {"fish_pond_1": 2}}, {"min_rarity": 3}
              </div>
            </div>
            
            <div class="section-title">Rewards</div>
            
            <div class="form-group">
              <label>Rewards (JSON)</label>
              <textarea id="quest-rewards" class="json-editor" placeholder='{"gold": 100}'></textarea>
              <div class="help-text">
                Examples: {"gold": 100}, {"gold": 50, "items": [{"item_id": "pole_2", "quantity": 1}]}
              </div>
            </div>
            
            <div class="btn-group">
              <button type="submit" class="btn btn-success" id="save-btn">Save Quest</button>
              <button type="button" class="btn btn-secondary" onclick="cancelEdit()">Cancel</button>
              <button type="button" class="btn btn-danger" id="delete-btn" onclick="deleteQuest()" style="margin-left: auto; display: none;">Delete</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
  
  <script>
    let quests = [];
    let selectedQuestId = null;
    let isEditing = false;
    
    async function loadQuests() {
      try {
        const res = await fetch('/api/quests');
        quests = await res.json();
        renderQuestList();
      } catch (error) {
        showToast('Failed to load quests', 'error');
      }
    }
    
    function renderQuestList() {
      const container = document.getElementById('quest-list');
      
      if (quests.length === 0) {
        container.innerHTML = '<div class="empty-state">No quests yet. Create one!</div>';
        return;
      }
      
      // Group by storyline
      const groups = {};
      const dailies = [];
      
      for (const quest of quests) {
        if (quest.questType === 'daily') {
          dailies.push(quest);
        } else {
          const storyline = quest.storyline || 'Uncategorized';
          if (!groups[storyline]) groups[storyline] = [];
          groups[storyline].push(quest);
        }
      }
      
      // Sort each group by story order
      for (const key of Object.keys(groups)) {
        groups[key].sort((a, b) => (a.storyOrder || 0) - (b.storyOrder || 0));
      }
      
      let html = '';
      
      // Render storyline groups
      for (const [storyline, groupQuests] of Object.entries(groups)) {
        html += \`<div class="storyline-group">
          <div class="storyline-header">\${storyline.replace(/_/g, ' ')}</div>
          \${groupQuests.map(q => renderQuestItem(q)).join('')}
        </div>\`;
      }
      
      // Render daily quests
      if (dailies.length > 0) {
        html += \`<div class="storyline-group">
          <div class="storyline-header">Daily Quests</div>
          \${dailies.map(q => renderQuestItem(q)).join('')}
        </div>\`;
      }
      
      container.innerHTML = html;
    }
    
    function renderQuestItem(quest) {
      const isSelected = selectedQuestId === quest.id;
      const badgeClass = quest.questType === 'story' ? 'badge-story' : 'badge-daily';
      return \`
        <div class="quest-item \${isSelected ? 'selected' : ''}" onclick="selectQuest('\${quest.id}')">
          <div class="quest-item-title">\${quest.title}</div>
          <div class="quest-item-meta">
            <span class="badge \${badgeClass}">\${quest.questType}</span>
            <span>\${quest.id}</span>
          </div>
        </div>
      \`;
    }
    
    function selectQuest(id) {
      selectedQuestId = id;
      isEditing = true;
      const quest = quests.find(q => q.id === id);
      if (!quest) return;
      
      document.getElementById('quest-id').value = quest.id;
      document.getElementById('quest-id').disabled = true;
      document.getElementById('quest-title').value = quest.title;
      document.getElementById('quest-description').value = quest.description;
      document.getElementById('quest-type').value = quest.questType;
      document.getElementById('quest-storyline').value = quest.storyline || '';
      document.getElementById('quest-order').value = quest.storyOrder || '';
      document.getElementById('quest-prereq').value = quest.prerequisiteQuestId || '';
      document.getElementById('quest-requirements').value = quest.requirements;
      document.getElementById('quest-rewards').value = quest.rewards;
      
      document.getElementById('editor-title').textContent = 'Edit Quest';
      document.getElementById('save-btn').textContent = 'Update Quest';
      document.getElementById('delete-btn').style.display = 'block';
      
      updateTypeFields();
      renderQuestList();
    }
    
    function newQuest() {
      selectedQuestId = null;
      isEditing = false;
      
      document.getElementById('quest-form').reset();
      document.getElementById('quest-id').disabled = false;
      document.getElementById('editor-title').textContent = 'New Quest';
      document.getElementById('save-btn').textContent = 'Create Quest';
      document.getElementById('delete-btn').style.display = 'none';
      
      updateTypeFields();
      renderQuestList();
    }
    
    async function seedQuests() {
      if (!confirm('This will add the default quests (if they don\\'t already exist). Continue?')) return;
      
      try {
        const res = await fetch('/api/quests/seed', { method: 'POST' });
        const data = await res.json();
        if (data.success) {
          showToast('Default quests seeded!', 'success');
          loadQuests();
        } else {
          showToast('Failed to seed quests', 'error');
        }
      } catch (error) {
        showToast('Error seeding quests', 'error');
      }
    }
    
    function cancelEdit() {
      newQuest();
    }
    
    function updateTypeFields() {
      const type = document.getElementById('quest-type').value;
      const storyFields = document.getElementById('story-fields');
      storyFields.style.display = type === 'story' ? 'block' : 'none';
    }
    
    async function saveQuest(e) {
      e.preventDefault();
      
      const quest = {
        id: document.getElementById('quest-id').value,
        title: document.getElementById('quest-title').value,
        description: document.getElementById('quest-description').value,
        questType: document.getElementById('quest-type').value,
        storyline: document.getElementById('quest-storyline').value || null,
        storyOrder: parseInt(document.getElementById('quest-order').value) || null,
        prerequisiteQuestId: document.getElementById('quest-prereq').value || null,
        requirements: document.getElementById('quest-requirements').value,
        rewards: document.getElementById('quest-rewards').value,
      };
      
      // Validate JSON
      try {
        JSON.parse(quest.requirements);
        JSON.parse(quest.rewards);
      } catch (err) {
        showToast('Invalid JSON in requirements or rewards', 'error');
        return;
      }
      
      try {
        const method = isEditing ? 'PUT' : 'POST';
        const url = isEditing ? '/api/quests/' + quest.id : '/api/quests';
        
        const res = await fetch(url, {
          method,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(quest),
        });
        
        const data = await res.json();
        
        if (data.success) {
          showToast(isEditing ? 'Quest updated!' : 'Quest created!', 'success');
          await loadQuests();
          if (!isEditing) {
            selectQuest(quest.id);
          }
        } else {
          showToast('Failed to save quest', 'error');
        }
      } catch (error) {
        showToast('Error saving quest', 'error');
      }
    }
    
    async function deleteQuest() {
      if (!selectedQuestId) return;
      if (!confirm('Delete this quest? This will also remove all player progress.')) return;
      
      try {
        const res = await fetch('/api/quests/' + selectedQuestId, { method: 'DELETE' });
        const data = await res.json();
        
        if (data.success) {
          showToast('Quest deleted', 'success');
          newQuest();
          await loadQuests();
        } else {
          showToast('Failed to delete quest', 'error');
        }
      } catch (error) {
        showToast('Error deleting quest', 'error');
      }
    }
    
    function showToast(message, type) {
      const toast = document.createElement('div');
      toast.className = 'toast toast-' + type;
      toast.textContent = message;
      document.body.appendChild(toast);
      setTimeout(() => toast.remove(), 3000);
    }
    
    // Initial load
    loadQuests();
    updateTypeFields();
  </script>
</body>
</html>`;

// =============================================================================
// Elysia Server
// =============================================================================

const app = new Elysia()
  // CORS for admin app
  .onRequest(({ request, set }) => {
    const origin = request.headers.get('Origin');
    if (origin) {
      set.headers['Access-Control-Allow-Origin'] = origin;
      set.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS';
      set.headers['Access-Control-Allow-Headers'] = 'Content-Type, X-Service-Key';
    }
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204 });
    }
  })
  // Service key auth for /api/* routes
  .onBeforeHandle(({ request, path }) => {
    if (path.startsWith('/api/')) {
      const authError = validateServiceKey(request);
      if (authError) return authError;
    }
  })
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

  // Debug endpoint to check bridge state
  .get('/api/debug', () => {
    return {
      connected: stdb.getIsConnected(),
      questCount: stdb.getQuests().length,
      quests: stdb.getQuests(),
    };
  })

  // Quest Admin API endpoints
  .get('/api/quests', () => {
    return stdb.getQuests();
  })

  .post('/api/quests', async ({ body }) => {
    const quest = body as any;
    const success = await stdb.adminCreateQuest({
      id: quest.id,
      title: quest.title,
      description: quest.description,
      questType: quest.questType,
      storyline: quest.storyline || null,
      storyOrder: quest.storyOrder || null,
      prerequisiteQuestId: quest.prerequisiteQuestId || null,
      requirements: quest.requirements,
      rewards: quest.rewards,
      questGiverType: quest.questGiverType || null,
      questGiverId: quest.questGiverId || null,
    });
    return { success };
  })

  .put('/api/quests/:id', async ({ params, body }) => {
    const quest = body as any;
    const success = await stdb.adminUpdateQuest({
      id: params.id,
      title: quest.title,
      description: quest.description,
      questType: quest.questType,
      storyline: quest.storyline || null,
      storyOrder: quest.storyOrder || null,
      prerequisiteQuestId: quest.prerequisiteQuestId || null,
      requirements: quest.requirements,
      rewards: quest.rewards,
      questGiverType: quest.questGiverType || null,
      questGiverId: quest.questGiverId || null,
    });
    return { success };
  })

  .delete('/api/quests/:id', async ({ params }) => {
    const success = await stdb.adminDeleteQuest(params.id);
    return { success };
  })

  .post('/api/quests/:id/reset-progress', async ({ params }) => {
    const success = await stdb.adminResetQuestProgress(params.id);
    return { success };
  })

  .post('/api/quests/seed', async () => {
    const success = await stdb.adminSeedQuests();
    return { success, message: success ? 'Default quests seeded' : 'Failed to seed quests' };
  })

  // Item Definition API endpoints
  .get('/api/items', () => {
    return stdb.getItemDefinitions();
  })

  .post('/api/items', async ({ body }) => {
    const item = body as any;
    const success = await stdb.adminCreateItem({
      id: item.id,
      name: item.name,
      category: item.category,
      waterType: item.waterType || null,
      tier: item.tier,
      buyPrice: item.buyPrice,
      sellPrice: item.sellPrice,
      stackSize: item.stackSize,
      spriteId: item.spriteId,
      description: item.description || null,
      isActive: item.isActive,
      rarityMultipliers: item.rarityMultipliers || null,
      metadata: item.metadata || null,
    });
    return { success };
  })

  .put('/api/items/:id', async ({ params, body }) => {
    const item = body as any;
    const success = await stdb.adminUpdateItem({
      id: params.id,
      name: item.name,
      category: item.category,
      waterType: item.waterType || null,
      tier: item.tier,
      buyPrice: item.buyPrice,
      sellPrice: item.sellPrice,
      stackSize: item.stackSize,
      spriteId: item.spriteId,
      description: item.description || null,
      isActive: item.isActive,
      rarityMultipliers: item.rarityMultipliers || null,
      metadata: item.metadata || null,
    });
    return { success };
  })

  .delete('/api/items/:id', async ({ params }) => {
    const success = await stdb.adminDeleteItem(params.id);
    return { success };
  })

  .post('/api/items/seed', async () => {
    const success = await stdb.adminSeedItems();
    return { success, message: success ? 'Default items seeded' : 'Failed to seed items' };
  })

  // Quest Admin page
  .get('/admin/quests', () => {
    return new Response(questAdminPageHtml, {
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

