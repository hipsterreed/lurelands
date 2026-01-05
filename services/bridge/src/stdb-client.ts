import { DbConnection, tables, reducers, type EventContext, type SubscriptionEventContext, type ErrorContext } from './generated';
import type { Player, Pond, River, Ocean, SpawnPoint, WorldState, FishCatch, InventoryItem, GameEvent, Quest, PlayerQuest } from './types';
import { stdbLogger } from './logger';

// =============================================================================
// SpacetimeDB Client Wrapper (using new spacetimedb SDK 1.4+)
// Following best practices from: https://spacetimedb.com/docs/sdks/typescript
// =============================================================================

export type PlayerUpdateCallback = (players: Player[]) => void;
export type WorldStateCallback = (worldState: WorldState) => void;
export type FishCaughtCallback = (fishCatch: FishCatch) => void;
export type InventoryUpdateCallback = (playerId: string, items: InventoryItem[]) => void;
export type GameEventCallback = (event: GameEvent) => void;
export type QuestUpdateCallback = (playerId: string, quests: Quest[], playerQuests: PlayerQuest[]) => void;

export class StdbClient {
  private conn: DbConnection | null = null;
  private isConnected = false;
  private authToken: string | null = null;  // Token persistence for reconnection
  
  // Cached world state
  private players: Map<string, Player> = new Map();
  private ponds: Pond[] = [];
  private rivers: River[] = [];
  private ocean: Ocean | null = null;
  private spawnPoints: SpawnPoint[] = [];
  
  // Inventory cache - Map<playerId, Map<"itemId:rarity", InventoryItem>>
  private inventory: Map<string, Map<string, InventoryItem>> = new Map();
  
  // Game events cache - recent events for the dashboard (max 200)
  private gameEvents: GameEvent[] = [];
  private static MAX_EVENTS = 200;

  // Quest caches
  private quests: Map<string, Quest> = new Map();
  private playerQuests: Map<string, Map<string, PlayerQuest>> = new Map(); // Map<playerId, Map<questId, PlayerQuest>>

  // Callbacks
  private onPlayersUpdate: PlayerUpdateCallback | null = null;
  private onWorldState: WorldStateCallback | null = null;
  private onFishCaught: FishCaughtCallback | null = null;
  private onInventoryUpdate: InventoryUpdateCallback | null = null;
  private onGameEvent: GameEventCallback | null = null;
  private onQuestUpdate: QuestUpdateCallback | null = null;

  constructor(
    private uri: string,
    private moduleName: string
  ) {}

  setCallbacks(callbacks: {
    onPlayersUpdate?: PlayerUpdateCallback;
    onWorldState?: WorldStateCallback;
    onFishCaught?: FishCaughtCallback;
    onInventoryUpdate?: InventoryUpdateCallback;
    onGameEvent?: GameEventCallback;
    onQuestUpdate?: QuestUpdateCallback;
  }) {
    this.onPlayersUpdate = callbacks.onPlayersUpdate ?? null;
    this.onWorldState = callbacks.onWorldState ?? null;
    this.onFishCaught = callbacks.onFishCaught ?? null;
    this.onInventoryUpdate = callbacks.onInventoryUpdate ?? null;
    this.onGameEvent = callbacks.onGameEvent ?? null;
    this.onQuestUpdate = callbacks.onQuestUpdate ?? null;
  }

  async connect(): Promise<boolean> {
    // Reset connection state
    this.isConnected = false;
    return new Promise((resolve) => {
      try {
        stdbLogger.info({ uri: this.uri, module: this.moduleName }, 'Connecting to SpacetimeDB');
        
        // Build connection with optional token for reconnection
        let builder = DbConnection.builder()
          .withUri(this.uri)
          .withModuleName(this.moduleName);
        
        // Use saved token if available (for reconnection with same identity)
        if (this.authToken) {
          stdbLogger.debug('Using saved auth token for reconnection');
          builder = builder.withToken(this.authToken);
        }
        
        this.conn = builder
          .onConnect((ctx, identity, token) => {
            stdbLogger.info({ identity: identity.toHexString() }, 'Connected');
            this.isConnected = true;
            
            // Save token for future reconnections (best practice from docs)
            this.authToken = token;
            
            // Subscribe to all tables with error handling
            ctx.subscriptionBuilder()
              .onApplied((subCtx: SubscriptionEventContext) => {
                stdbLogger.info('Subscription applied, loading initial state');
                this.loadInitialState(subCtx);
              })
              .onError((errCtx: ErrorContext) => {
                // Handle subscription errors (best practice from docs)
                stdbLogger.error({ event: errCtx.event }, 'Subscription error');
                // Log a helpful message about potential schema mismatches
                stdbLogger.error('If you see deserialization errors, the SpacetimeDB module may need to be rebuilt and redeployed.');
              })
              .subscribe([
                'SELECT * FROM spawn_point',
                'SELECT * FROM pond',
                'SELECT * FROM river',
                'SELECT * FROM ocean',
                'SELECT * FROM player',
                'SELECT * FROM fish_catch',
                'SELECT * FROM inventory',
                'SELECT * FROM game_event',
                'SELECT * FROM quest',
                'SELECT * FROM player_quest',
              ]);
            
            resolve(true);
          })
          .onConnectError((ctx: ErrorContext, error) => {
            stdbLogger.error({ err: error }, 'Connection error');
            this.isConnected = false;
            resolve(false);
          })
          .onDisconnect((ctx) => {
            stdbLogger.warn('Disconnected');
            this.isConnected = false;
          })
          .build();

        // Set up table callbacks before any data arrives
        this.setupTableCallbacks();

      } catch (error) {
        stdbLogger.error({ err: error }, 'Connection failed');
        this.isConnected = false;
        resolve(false);
      }
    });
  }

  private loadInitialState(ctx: SubscriptionEventContext) {
    try {
      // Load spawn points
      this.spawnPoints = [];
      for (const sp of ctx.db.spawnPoint.iter()) {
        this.spawnPoints.push({
          id: sp.id,
          x: sp.x,
          y: sp.y,
          name: sp.name,
        });
      }
      // Load ponds
      this.ponds = [];
      for (const p of ctx.db.pond.iter()) {
        this.ponds.push({
          id: p.id,
          x: p.x,
          y: p.y,
          radius: p.radius,
        });
      }

      // Load rivers
      this.rivers = [];
      for (const r of ctx.db.river.iter()) {
        this.rivers.push({
          id: r.id,
          x: r.x,
          y: r.y,
          width: r.width,
          length: r.length,
          rotation: r.rotation,
        });
      }

      // Load ocean
      this.ocean = null;
      for (const o of ctx.db.ocean.iter()) {
        this.ocean = {
          id: o.id,
          x: o.x,
          y: o.y,
          width: o.width,
          height: o.height,
        };
        break; // Only one ocean
      }

      // Load players - handle schema mismatch gracefully
      this.players.clear();
      try {
        for (const p of ctx.db.player.iter()) {
          this.players.set(p.id, this.mapPlayer(p));
        }
      } catch (error: any) {
        stdbLogger.error({ err: error }, 'Error loading players - schema mismatch?');
        if (error?.message?.includes('RangeError') || error?.message?.includes('deserialize')) {
          stdbLogger.error('CRITICAL: Schema mismatch detected! The deployed SpacetimeDB module does not match the expected schema.');
          stdbLogger.error('Please rebuild and redeploy the Rust module:');
          stdbLogger.error('  1. cd services/spacetime-server');
          stdbLogger.error('  2. cargo build --release --target wasm32-unknown-unknown');
          stdbLogger.error('  3. spacetime publish lurelands');
          stdbLogger.error('  4. cd ../bridge && bun run generate');
        }
        throw error; // Re-throw to prevent partial state
      }

      // Load inventory
      this.inventory.clear();
      try {
        for (const inv of ctx.db.inventory.iter()) {
          this.cacheInventoryItem(inv);
        }
      } catch (error: any) {
        stdbLogger.warn({ err: error }, 'Error loading inventory - table may not exist yet');
      }

      // Load game events (most recent ones)
      this.gameEvents = [];
      try {
        let eventCount = 0;
        for (const event of ctx.db.gameEvent.iter()) {
          const mapped = this.cacheGameEvent(event);
          this.gameEvents.push(mapped);
          eventCount++;
        }
        stdbLogger.info({ count: eventCount }, 'Loaded game events from SpacetimeDB');
        // Sort by createdAt descending (newest first)
        this.gameEvents.sort((a, b) => Number(b.createdAt) - Number(a.createdAt));
        // Keep only the most recent events
        if (this.gameEvents.length > StdbClient.MAX_EVENTS) {
          this.gameEvents = this.gameEvents.slice(0, StdbClient.MAX_EVENTS);
        }
      } catch (error: any) {
        stdbLogger.warn({ err: error }, 'Error loading game events - table may not exist yet');
      }

      // Load quests
      this.quests.clear();
      try {
        let questCount = 0;
        for (const quest of ctx.db.quest.iter()) {
          stdbLogger.debug({ questId: quest.id, title: quest.title }, 'Loading quest from DB');
          this.cacheQuest(quest);
          questCount++;
        }
        stdbLogger.info({ questCount }, 'Finished loading quests from DB');
      } catch (error: any) {
        stdbLogger.error({ err: error, errMessage: error?.message, errStack: error?.stack }, 'Error loading quests - table may not exist yet');
      }

      // Load player quests
      this.playerQuests.clear();
      try {
        for (const pq of ctx.db.playerQuest.iter()) {
          this.cachePlayerQuest(pq);
        }
      } catch (error: any) {
        stdbLogger.warn({ err: error }, 'Error loading player quests - table may not exist yet');
      }

      stdbLogger.info({
        spawnPoints: this.spawnPoints.length,
        ponds: this.ponds.length,
        rivers: this.rivers.length,
        hasOcean: !!this.ocean,
        players: this.players.size,
        inventoryEntries: Array.from(this.inventory.values()).reduce((sum, map) => sum + map.size, 0),
        gameEvents: this.gameEvents.length,
        quests: this.quests.size,
        playerQuests: Array.from(this.playerQuests.values()).reduce((sum, map) => sum + map.size, 0),
      }, 'Initial state loaded');

      // Emit callbacks
      this.emitWorldState();
      this.emitPlayersUpdate();
    } catch (error: any) {
      stdbLogger.error({ err: error }, 'Failed to load initial state');
      if (error?.message?.includes('RangeError') || error?.message?.includes('deserialize')) {
        stdbLogger.error('Schema mismatch! Rebuild and redeploy the SpacetimeDB module.');
      }
      throw error;
    }
  }

  private setupTableCallbacks() {
    if (!this.conn) return;

    // Player table callbacks
    this.conn.db.player.onInsert((ctx: EventContext, player) => {
      stdbLogger.debug({ playerId: player.id }, 'Player inserted');
      this.players.set(player.id, this.mapPlayer(player));
      this.emitPlayersUpdate();
    });

    this.conn.db.player.onUpdate((ctx: EventContext, oldPlayer, newPlayer) => {
      this.players.set(newPlayer.id, this.mapPlayer(newPlayer));
      this.emitPlayersUpdate();
    });

    this.conn.db.player.onDelete((ctx: EventContext, player) => {
      stdbLogger.debug({ playerId: player.id }, 'Player deleted');
      this.players.delete(player.id);
      this.emitPlayersUpdate();
    });

    // Fish catch callback
    this.conn.db.fishCatch.onInsert((ctx: EventContext, fc) => {
      stdbLogger.info({ playerId: fc.playerId, fishType: fc.fishType, rarity: fc.rarity }, 'Fish caught');
      if (this.onFishCaught) {
        this.onFishCaught({
          id: Number(fc.id),
          fishId: fc.fishId,
          playerId: fc.playerId,
          fishType: fc.fishType,
          size: fc.size,
          rarity: fc.rarity,
          waterBodyId: fc.waterBodyId,
          released: fc.released,
        });
      }
    });

    // Inventory callbacks
    this.conn.db.inventory.onInsert((ctx: EventContext, inv) => {
      stdbLogger.debug({ playerId: inv.playerId, itemId: inv.itemId, rarity: inv.rarity, qty: inv.quantity }, 'Inventory item inserted');
      this.cacheInventoryItem(inv);
      this.emitInventoryUpdate(inv.playerId);
    });

    this.conn.db.inventory.onUpdate((ctx: EventContext, oldInv, newInv) => {
      stdbLogger.debug({ playerId: newInv.playerId, itemId: newInv.itemId, qty: newInv.quantity }, 'Inventory item updated');
      this.cacheInventoryItem(newInv);
      this.emitInventoryUpdate(newInv.playerId);
    });

    this.conn.db.inventory.onDelete((ctx: EventContext, inv) => {
      stdbLogger.debug({ playerId: inv.playerId, itemId: inv.itemId }, 'Inventory item deleted');
      const playerInv = this.inventory.get(inv.playerId);
      if (playerInv) {
        // Use the database row ID as key (same as cacheInventoryItem)
        playerInv.delete(String(inv.id));
      }
      this.emitInventoryUpdate(inv.playerId);
    });

    // Game event callback
    this.conn.db.gameEvent.onInsert((ctx: EventContext, event) => {
      stdbLogger.info({ eventType: event.eventType, playerId: event.playerId, id: Number(event.id) }, 'Game event received from SpacetimeDB');
      const mapped = this.cacheGameEvent(event);
      this.addGameEvent(mapped);
    });

    // Quest callbacks
    this.conn.db.quest.onInsert((ctx: EventContext, quest) => {
      stdbLogger.debug({ questId: quest.id, title: quest.title }, 'Quest inserted');
      this.cacheQuest(quest);
    });

    this.conn.db.quest.onUpdate((ctx: EventContext, oldQuest, newQuest) => {
      this.cacheQuest(newQuest);
    });

    this.conn.db.quest.onDelete((ctx: EventContext, quest) => {
      stdbLogger.debug({ questId: quest.id }, 'Quest deleted');
      this.quests.delete(quest.id);
    });

    // Player quest callbacks
    this.conn.db.playerQuest.onInsert((ctx: EventContext, pq) => {
      stdbLogger.debug({ playerId: pq.playerId, questId: pq.questId, status: pq.status }, 'Player quest inserted');
      this.cachePlayerQuest(pq);
      this.emitQuestUpdate(pq.playerId);
    });

    this.conn.db.playerQuest.onUpdate((ctx: EventContext, oldPq, newPq) => {
      stdbLogger.debug({ playerId: newPq.playerId, questId: newPq.questId, status: newPq.status }, 'Player quest updated');
      this.cachePlayerQuest(newPq);
      this.emitQuestUpdate(newPq.playerId);
    });

    this.conn.db.playerQuest.onDelete((ctx: EventContext, pq) => {
      stdbLogger.debug({ playerId: pq.playerId, questId: pq.questId }, 'Player quest deleted');
      const playerQs = this.playerQuests.get(pq.playerId);
      if (playerQs) {
        playerQs.delete(pq.questId);
      }
      this.emitQuestUpdate(pq.playerId);
    });
  }

  // --- Inventory helpers ---

  private cacheInventoryItem(inv: any) {
    const playerId = inv.playerId;
    if (!this.inventory.has(playerId)) {
      this.inventory.set(playerId, new Map());
    }
    // Use the database row ID as key since items may not stack (e.g., poles)
    const key = String(inv.id);
    this.inventory.get(playerId)!.set(key, {
      id: Number(inv.id),
      playerId: inv.playerId,
      itemId: inv.itemId,
      rarity: inv.rarity,
      quantity: inv.quantity,
    });
  }

  private emitInventoryUpdate(playerId: string) {
    if (this.onInventoryUpdate) {
      const items = this.getPlayerInventory(playerId);
      this.onInventoryUpdate(playerId, items);
    }
  }

  // --- Game Event helpers ---

  private cacheGameEvent(event: any): GameEvent {
    const mapped: GameEvent = {
      id: Number(event.id),
      playerId: event.playerId,
      sessionId: event.sessionId ? Number(event.sessionId) : null,
      eventType: event.eventType,
      itemId: event.itemId ?? null,
      quantity: event.quantity ?? null,
      goldAmount: event.goldAmount ?? null,
      rarity: event.rarity ?? null,
      waterBodyId: event.waterBodyId ?? null,
      metadata: event.metadata ?? null,
      createdAt: Number(event.createdAt),
    };
    return mapped;
  }

  private addGameEvent(event: GameEvent) {
    // Add to front (newest first)
    this.gameEvents.unshift(event);
    // Keep max size
    if (this.gameEvents.length > StdbClient.MAX_EVENTS) {
      this.gameEvents.pop();
    }
    // Emit callback
    if (this.onGameEvent) {
      this.onGameEvent(event);
    }
  }

  // --- Quest helpers ---

  private cacheQuest(quest: any) {
    this.quests.set(quest.id, {
      id: quest.id,
      title: quest.title,
      description: quest.description,
      questType: quest.questType as 'story' | 'daily',
      storyline: quest.storyline ?? null,
      storyOrder: quest.storyOrder ?? null,
      prerequisiteQuestId: quest.prerequisiteQuestId ?? null,
      requirements: quest.requirements,
      rewards: quest.rewards,
    });
  }

  private cachePlayerQuest(pq: any) {
    const playerId = pq.playerId;
    if (!this.playerQuests.has(playerId)) {
      this.playerQuests.set(playerId, new Map());
    }
    this.playerQuests.get(playerId)!.set(pq.questId, {
      id: Number(pq.id),
      playerId: pq.playerId,
      questId: pq.questId,
      status: pq.status as 'available' | 'active' | 'completed',
      progress: pq.progress,
      acceptedAt: pq.acceptedAt ? Number(pq.acceptedAt) : null,
      completedAt: pq.completedAt ? Number(pq.completedAt) : null,
    });
  }

  private emitQuestUpdate(playerId: string) {
    if (this.onQuestUpdate) {
      const quests = this.getQuests();
      const playerQs = this.getPlayerQuests(playerId);
      this.onQuestUpdate(playerId, quests, playerQs);
    }
  }

  // --- Mapping functions ---

  private mapPlayer(p: any): Player {
    return {
      id: p.id,
      name: p.name,
      x: p.x,
      y: p.y,
      facingAngle: p.facingAngle ?? 0,
      isCasting: p.isCasting ?? false,
      castTargetX: p.castTargetX ?? null,
      castTargetY: p.castTargetY ?? null,
      color: p.color ?? 0xFFE74C3C,
      isOnline: p.isOnline ?? true,
      gold: p.gold ?? 0,
      equippedPoleId: p.equippedPoleId ?? null,
    };
  }

  // --- Emit callbacks ---

  private emitPlayersUpdate() {
    if (this.onPlayersUpdate) {
      this.onPlayersUpdate(Array.from(this.players.values()));
    }
  }

  private emitWorldState() {
    if (this.onWorldState) {
      this.onWorldState({
        spawnPoints: this.spawnPoints,
        ponds: this.ponds,
        rivers: this.rivers,
        ocean: this.ocean,
      });
    }
  }

  // --- Reducer calls ---
  // NOTE: SpacetimeDB SDK expects reducers to be called with a single params OBJECT,
  // not positional arguments. The property names must match the generated schema.

  async joinWorld(playerId: string, name: string, color: number): Promise<{ x: number; y: number } | null> {
    stdbLogger.debug({ playerId, name, color }, 'joinWorld called');
    
    if (!this.conn || !this.isConnected) {
      stdbLogger.warn('Not connected, cannot join world');
      return null;
    }

    try {
      // Check if player already exists - if so, use their existing position
      const existingPlayer = this.getPlayer(playerId);
      if (existingPlayer) {
        stdbLogger.info({ playerId, x: existingPlayer.x, y: existingPlayer.y }, 'Player reconnecting, using existing position');
        // Call reducer to update timestamp but preserve existing data
        this.conn.reducers.joinWorld({ playerId, name, color: color >>> 0 });
        return { x: existingPlayer.x, y: existingPlayer.y };
      }

      // New player - call reducer to create them
      this.conn.reducers.joinWorld({ playerId, name, color: color >>> 0 });
      
      // Pick a random spawn point for new players
      const spawn = this.spawnPoints.length > 0
        ? this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)]
        : { x: 1000, y: 1000, id: 'default', name: 'Default Spawn' };
      
      // Add to local cache optimistically so buyItem works immediately
      // Without this, there's a race condition where the player tries to buy
      // before the SpacetimeDB insert callback fires
      const newPlayer: Player = {
        id: playerId,
        name,
        x: spawn.x,
        y: spawn.y,
        facingAngle: 0,
        isCasting: false,
        castTargetX: null,
        castTargetY: null,
        color,
        isOnline: true,
        gold: 0,
        equippedPoleId: null,
      };
      this.players.set(playerId, newPlayer);
      this.emitPlayersUpdate();
      
      stdbLogger.info({ playerId, spawn: spawn.name }, 'New player spawned');
      return { x: spawn.x, y: spawn.y };
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to join world');
      return null;
    }
  }

  async leaveWorld(playerId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.leaveWorld({ playerId });
      stdbLogger.debug({ playerId }, 'Player left world');
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to leave world');
    }
  }

  private _lastPositionLog = 0;
  
  async updatePosition(playerId: string, x: number, y: number, facingAngle: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.updatePosition({ playerId, x, y, facingAngle });
      
      // Log once per second max (trace level for high-frequency updates)
      const now = Date.now();
      if (now - this._lastPositionLog > 1000) {
        stdbLogger.trace({ playerId: playerId.substring(0, 10), x: x.toFixed(0), y: y.toFixed(0) }, 'Position update');
        this._lastPositionLog = now;
      }
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Position update error');
    }
  }

  async startCasting(playerId: string, targetX: number, targetY: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.startCasting({ playerId, targetX, targetY });
      stdbLogger.debug({ playerId, targetX, targetY }, 'Started casting');
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to start casting');
    }
  }

  async stopCasting(playerId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.stopCasting({ playerId });
      stdbLogger.debug({ playerId }, 'Stopped casting');
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to stop casting');
    }
  }

  async updatePlayerName(playerId: string, name: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.updatePlayerName({ playerId, name });
      stdbLogger.info({ playerId, name }, 'Updated player name');
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to update player name');
    }
  }

  async catchFish(playerId: string, itemId: string, rarity: number, waterBodyId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      // Extract fish_type from itemId (e.g., "fish_ocean_1" -> "ocean")
      const parts = itemId.split('_');
      const fishType = parts.length >= 2 ? parts[1] : 'unknown';
      
      // Persist to SpacetimeDB - the onInsert callback will update the cache
      // We don't do optimistic updates here to avoid duplicate entries
      this.conn.reducers.catchFish({
        playerId,
        itemId,
        fishType,
        size: 1.0, // Default size for now
        rarity,
        waterBodyId,
      });
      stdbLogger.info({ playerId, itemId, rarity, waterBodyId }, 'Caught fish');
    } catch (error) {
      stdbLogger.error({ err: error, playerId, itemId }, 'Failed to catch fish');
    }
  }

  async sellItem(playerId: string, itemId: string, rarity: number, quantity: number, inventoryId?: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Call atomic sell_item reducer (handles gold, inventory, and logging atomically)
      // The onUpdate/onDelete callbacks will update the inventory cache
      // The player update callback will update gold
      this.conn.reducers.sellItem({
        playerId,
        itemId,
        rarity,
        quantity,
      });
      
      stdbLogger.info({ playerId, itemId, rarity, quantity }, 'Selling item (atomic reducer)');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, itemId, quantity }, 'Failed to sell item');
    }
  }

  async buyItem(playerId: string, itemId: string, price: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Check if player has enough gold (client-side validation for UX)
      const player = this.players.get(playerId);
      if (!player || player.gold < price) {
        stdbLogger.warn({ playerId, itemId, price, gold: player?.gold ?? 0 }, 'Not enough gold to buy item');
        return;
      }
      
      // Optimistic update: deduct gold locally (will be corrected by server if needed)
      player.gold -= price;
      this.players.set(playerId, player);
      this.broadcastPlayersUpdate();
      
      // Call atomic buy_item reducer (handles gold, inventory, and logging atomically)
      // Server will validate gold and calculate price authoritatively
      // The onInsert callback will update the inventory cache
      this.conn.reducers.buyItem({
        playerId,
        itemId,
      });
      
      stdbLogger.info({ playerId, itemId, price }, 'Bought item (atomic reducer)');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, itemId, price }, 'Failed to buy item');
    }
  }

  private broadcastPlayersUpdate(): void {
    if (this.onPlayersUpdate) {
      this.onPlayersUpdate(Array.from(this.players.values()));
    }
  }

  async equipPole(playerId: string, poleItemId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Check if player owns this pole
      const playerInv = this.inventory.get(playerId);
      if (!playerInv) {
        stdbLogger.warn({ playerId }, 'No inventory found for player');
        return;
      }
      
      // Find the pole in inventory by searching through values
      // (inventory is keyed by database ID, not itemId:rarity)
      let hasPole = false;
      for (const item of playerInv.values()) {
        if (item.itemId === poleItemId && item.quantity > 0) {
          hasPole = true;
          break;
        }
      }
      if (!hasPole) {
        stdbLogger.warn({ playerId, poleItemId }, 'Player does not own this pole');
        return;
      }
      
      // Update local player state (optimistic update)
      const player = this.players.get(playerId);
      if (player) {
        player.equippedPoleId = poleItemId;
        this.players.set(playerId, player);
        this.broadcastPlayersUpdate();
      }
      
      // Call SpacetimeDB reducer
      this.conn.reducers.equipPole({
        playerId,
        poleItemId,
      });
      
      stdbLogger.info({ playerId, poleItemId }, 'Equipped pole');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, poleItemId }, 'Failed to equip pole');
    }
  }

  async unequipPole(playerId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Update local player state (optimistic update)
      const player = this.players.get(playerId);
      if (player) {
        stdbLogger.info({ playerId, previousPole: player.equippedPoleId }, 'Unequipping pole');
        player.equippedPoleId = null;
        this.players.set(playerId, player);
        this.broadcastPlayersUpdate();
      }
      
      // Call SpacetimeDB reducer
      this.conn.reducers.unequipPole({
        playerId,
      });
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId }, 'Failed to unequip pole');
    }
  }

  async setGold(playerId: string, amount: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Update local player state (optimistic update)
      const player = this.players.get(playerId);
      if (player) {
        stdbLogger.info({ playerId, oldGold: player.gold, newGold: amount }, 'Setting gold');
        player.gold = amount;
        this.players.set(playerId, player);
        this.broadcastPlayersUpdate();
      }
      
      // Call SpacetimeDB reducer
      this.conn.reducers.setGold({
        playerId,
        amount,
      });
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, amount }, 'Failed to set gold');
    }
  }

  // --- Getters ---

  getWorldState(): WorldState {
    return {
      spawnPoints: this.spawnPoints,
      ponds: this.ponds,
      rivers: this.rivers,
      ocean: this.ocean,
    };
  }

  getPlayers(): Player[] {
    return Array.from(this.players.values());
  }

  getPlayer(playerId: string): Player | null {
    // First check the in-memory cache
    const cached = this.players.get(playerId);
    if (cached) {
      return cached;
    }

    // If not in cache, query the database directly by iterating
    // (The cache should have all players after loadInitialState, but this is a fallback)
    if (this.conn) {
      try {
        for (const player of this.conn.db.player.iter()) {
          if (player.id === playerId) {
            const mapped = this.mapPlayer(player);
            // Cache it for future lookups
            this.players.set(playerId, mapped);
            return mapped;
          }
        }
      } catch (error) {
        stdbLogger.error({ err: error, playerId }, 'Error querying player from database');
      }
    }

    return null;
  }

  getIsConnected(): boolean {
    return this.isConnected;
  }

  getPlayerInventory(playerId: string): InventoryItem[] {
    const playerInv = this.inventory.get(playerId);
    if (!playerInv) return [];
    return Array.from(playerInv.values());
  }

  getGameEvents(limit?: number): GameEvent[] {
    if (limit && limit > 0) {
      return this.gameEvents.slice(0, limit);
    }
    return [...this.gameEvents];
  }

  // --- Quest methods ---

  getQuests(): Quest[] {
    return Array.from(this.quests.values());
  }

  getPlayerQuests(playerId: string): PlayerQuest[] {
    const playerQs = this.playerQuests.get(playerId);
    if (!playerQs) return [];
    return Array.from(playerQs.values());
  }

  async acceptQuest(playerId: string, questId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Check if quest exists
      const quest = this.quests.get(questId);
      if (!quest) {
        stdbLogger.warn({ playerId, questId }, 'Quest not found');
        return;
      }
      
      // Optimistic update - add to local cache
      let playerQs = this.playerQuests.get(playerId);
      if (!playerQs) {
        playerQs = new Map();
        this.playerQuests.set(playerId, playerQs);
      }
      
      const tempPq: PlayerQuest = {
        id: Date.now(), // Temporary ID
        playerId,
        questId,
        status: 'active',
        progress: '{}',
        acceptedAt: Date.now() * 1000, // Microseconds
        completedAt: null,
      };
      playerQs.set(questId, tempPq);
      
      // Emit update immediately
      this.emitQuestUpdate(playerId);
      
      // Call SpacetimeDB reducer
      this.conn.reducers.acceptQuest({ playerId, questId });
      
      stdbLogger.info({ playerId, questId, title: quest.title }, 'Accepted quest');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, questId }, 'Failed to accept quest');
    }
  }

  async completeQuest(playerId: string, questId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Check if player has this quest active
      const playerQs = this.playerQuests.get(playerId);
      if (!playerQs || !playerQs.has(questId)) {
        stdbLogger.warn({ playerId, questId }, 'Player does not have this quest');
        return;
      }
      
      const pq = playerQs.get(questId)!;
      if (pq.status !== 'active') {
        stdbLogger.warn({ playerId, questId, status: pq.status }, 'Quest is not active');
        return;
      }
      
      // Optimistic update
      pq.status = 'completed';
      pq.completedAt = Date.now() * 1000;
      playerQs.set(questId, pq);
      
      // Emit update immediately
      this.emitQuestUpdate(playerId);
      
      // Call SpacetimeDB reducer
      this.conn.reducers.completeQuest({ playerId, questId });
      
      stdbLogger.info({ playerId, questId }, 'Completed quest');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, questId }, 'Failed to complete quest');
    }
  }

  // --- Admin Quest Methods ---

  async adminCreateQuest(quest: {
    id: string;
    title: string;
    description: string;
    questType: string;
    storyline: string | null;
    storyOrder: number | null;
    prerequisiteQuestId: string | null;
    requirements: string;
    rewards: string;
  }): Promise<boolean> {
    if (!this.conn || !this.isConnected) return false;
    
    try {
      this.conn.reducers.adminCreateQuest({
        id: quest.id,
        title: quest.title,
        description: quest.description,
        questType: quest.questType,
        storyline: quest.storyline ?? undefined,
        storyOrder: quest.storyOrder ?? undefined,
        prerequisiteQuestId: quest.prerequisiteQuestId ?? undefined,
        requirements: quest.requirements,
        rewards: quest.rewards,
      });
      
      stdbLogger.info({ questId: quest.id, title: quest.title }, 'Admin created quest');
      return true;
    } catch (error) {
      stdbLogger.error({ err: error, quest }, 'Failed to create quest');
      return false;
    }
  }

  async adminUpdateQuest(quest: {
    id: string;
    title: string;
    description: string;
    questType: string;
    storyline: string | null;
    storyOrder: number | null;
    prerequisiteQuestId: string | null;
    requirements: string;
    rewards: string;
  }): Promise<boolean> {
    if (!this.conn || !this.isConnected) return false;
    
    try {
      this.conn.reducers.adminUpdateQuest({
        id: quest.id,
        title: quest.title,
        description: quest.description,
        questType: quest.questType,
        storyline: quest.storyline ?? undefined,
        storyOrder: quest.storyOrder ?? undefined,
        prerequisiteQuestId: quest.prerequisiteQuestId ?? undefined,
        requirements: quest.requirements,
        rewards: quest.rewards,
      });
      
      stdbLogger.info({ questId: quest.id, title: quest.title }, 'Admin updated quest');
      return true;
    } catch (error) {
      stdbLogger.error({ err: error, quest }, 'Failed to update quest');
      return false;
    }
  }

  async adminDeleteQuest(questId: string): Promise<boolean> {
    if (!this.conn || !this.isConnected) return false;
    
    try {
      this.conn.reducers.adminDeleteQuest({ id: questId });
      
      stdbLogger.info({ questId }, 'Admin deleted quest');
      return true;
    } catch (error) {
      stdbLogger.error({ err: error, questId }, 'Failed to delete quest');
      return false;
    }
  }

  async adminResetQuestProgress(questId: string): Promise<boolean> {
    if (!this.conn || !this.isConnected) return false;
    
    try {
      this.conn.reducers.adminResetQuestProgress({ questId });
      
      stdbLogger.info({ questId }, 'Admin reset quest progress');
      return true;
    } catch (error) {
      stdbLogger.error({ err: error, questId }, 'Failed to reset quest progress');
      return false;
    }
  }

  async adminSeedQuests(): Promise<boolean> {
    if (!this.conn || !this.isConnected) {
      stdbLogger.warn('Not connected to SpacetimeDB, cannot seed quests');
      return false;
    }

    try {
      this.conn.reducers.adminSeedQuests({});
      stdbLogger.info('Admin triggered quest seeding');
      return true;
    } catch (error) {
      stdbLogger.error({ err: error }, 'Failed to seed quests');
      return false;
    }
  }

  disconnect() {
    if (this.conn) {
      this.conn.disconnect();
      this.conn = null;
    }
    this.isConnected = false;
    this.players.clear();
    this.inventory.clear();
    this.gameEvents = [];
    this.quests.clear();
    this.playerQuests.clear();
  }
}
