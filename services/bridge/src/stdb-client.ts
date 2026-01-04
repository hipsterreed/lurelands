import { DbConnection, tables, reducers, type EventContext, type SubscriptionEventContext, type ErrorContext } from './generated';
import type { Player, Pond, River, Ocean, SpawnPoint, WorldState, FishCatch, InventoryItem } from './types';
import { stdbLogger } from './logger';

// =============================================================================
// SpacetimeDB Client Wrapper (using new spacetimedb SDK 1.4+)
// Following best practices from: https://spacetimedb.com/docs/sdks/typescript
// =============================================================================

export type PlayerUpdateCallback = (players: Player[]) => void;
export type WorldStateCallback = (worldState: WorldState) => void;
export type FishCaughtCallback = (fishCatch: FishCatch) => void;
export type InventoryUpdateCallback = (playerId: string, items: InventoryItem[]) => void;

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

  // Callbacks
  private onPlayersUpdate: PlayerUpdateCallback | null = null;
  private onWorldState: WorldStateCallback | null = null;
  private onFishCaught: FishCaughtCallback | null = null;
  private onInventoryUpdate: InventoryUpdateCallback | null = null;

  constructor(
    private uri: string,
    private moduleName: string
  ) {}

  setCallbacks(callbacks: {
    onPlayersUpdate?: PlayerUpdateCallback;
    onWorldState?: WorldStateCallback;
    onFishCaught?: FishCaughtCallback;
    onInventoryUpdate?: InventoryUpdateCallback;
  }) {
    this.onPlayersUpdate = callbacks.onPlayersUpdate ?? null;
    this.onWorldState = callbacks.onWorldState ?? null;
    this.onFishCaught = callbacks.onFishCaught ?? null;
    this.onInventoryUpdate = callbacks.onInventoryUpdate ?? null;
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

      stdbLogger.info({
        spawnPoints: this.spawnPoints.length,
        ponds: this.ponds.length,
        rivers: this.rivers.length,
        hasOcean: !!this.ocean,
        players: this.players.size,
        inventoryEntries: Array.from(this.inventory.values()).reduce((sum, map) => sum + map.size, 0),
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
        playerInv.delete(`${inv.itemId}:${inv.rarity}`);
      }
      this.emitInventoryUpdate(inv.playerId);
    });
  }

  // --- Inventory helpers ---

  private cacheInventoryItem(inv: any) {
    const playerId = inv.playerId;
    if (!this.inventory.has(playerId)) {
      this.inventory.set(playerId, new Map());
    }
    const key = `${inv.itemId}:${inv.rarity}`;
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
      if (this.spawnPoints.length > 0) {
        const spawn = this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)];
        stdbLogger.info({ playerId, spawn: spawn.name }, 'New player spawned');
        return { x: spawn.x, y: spawn.y };
      }
      return { x: 1000, y: 1000 };
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

  async sellItem(playerId: string, itemId: string, rarity: number, quantity: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Get the player's inventory
      const playerInv = this.inventory.get(playerId);
      if (!playerInv) {
        stdbLogger.warn({ playerId }, 'No inventory found for player');
        return;
      }
      
      // Find the item stack
      const stackKey = `${itemId}:${rarity}`;
      const item = playerInv.get(stackKey);
      if (!item || item.quantity < quantity) {
        stdbLogger.warn({ playerId, itemId, rarity, quantity, available: item?.quantity ?? 0 }, 'Not enough items to sell');
        return;
      }
      
      // Calculate sell price based on item type
      const sellPrice = this.calculateSellPrice(itemId, rarity);
      const totalGold = sellPrice * quantity;
      
      // Update local inventory
      const newQuantity = item.quantity - quantity;
      if (newQuantity <= 0) {
        playerInv.delete(stackKey);
      } else {
        item.quantity = newQuantity;
        playerInv.set(stackKey, item);
      }
      
      // Update local player gold (optimistic update)
      const player = this.players.get(playerId);
      if (player) {
        player.gold += totalGold;
        this.players.set(playerId, player);
        this.broadcastPlayersUpdate();
      }
      
      // Persist gold change to SpacetimeDB
      this.conn.reducers.addGold({
        playerId,
        amount: totalGold,
      });
      
      // Remove items from inventory in SpacetimeDB
      this.conn.reducers.removeFromInventory({
        playerId,
        itemId,
        rarity,
        quantity,
      });
      
      // Notify inventory update
      if (this.onInventoryUpdate) {
        this.onInventoryUpdate(playerId, Array.from(playerInv.values()));
      }
      
      stdbLogger.info({ playerId, itemId, rarity, quantity, totalGold }, 'Sold item, updated gold and inventory');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, itemId, quantity }, 'Failed to sell item');
    }
  }

  async buyItem(playerId: string, itemId: string, price: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    
    try {
      // Check if player has enough gold
      const player = this.players.get(playerId);
      if (!player || player.gold < price) {
        stdbLogger.warn({ playerId, itemId, price, gold: player?.gold ?? 0 }, 'Not enough gold to buy item');
        return;
      }
      
      // Deduct gold locally (optimistic update)
      player.gold -= price;
      this.players.set(playerId, player);
      this.broadcastPlayersUpdate();
      
      // Get or create player inventory
      let playerInv = this.inventory.get(playerId);
      if (!playerInv) {
        playerInv = new Map();
        this.inventory.set(playerId, playerInv);
      }
      
      // Add item to local inventory (rarity 0 for non-fish items like poles)
      const stackKey = `${itemId}:0`;
      const existingItem = playerInv.get(stackKey);
      if (existingItem) {
        existingItem.quantity += 1;
        playerInv.set(stackKey, existingItem);
      } else {
        const newItem: import('./types').InventoryItem = {
          id: Date.now(), // Temporary ID
          playerId,
          itemId,
          rarity: 0,
          quantity: 1,
        };
        playerInv.set(stackKey, newItem);
      }
      
      // Persist to SpacetimeDB - deduct gold
      // Note: We use a negative gold add for now (or implement a separate reducer)
      // For now, we'll add the item to inventory and track gold locally
      this.conn.reducers.addToInventory({
        playerId,
        itemId,
        rarity: 0,
        quantity: 1,
      });
      
      // Deduct gold via a custom approach - for now just track locally
      // TODO: Add a spendGold reducer to the server
      
      // Notify inventory update
      if (this.onInventoryUpdate) {
        this.onInventoryUpdate(playerId, Array.from(playerInv.values()));
      }
      
      stdbLogger.info({ playerId, itemId, price }, 'Bought item');
      
    } catch (error) {
      stdbLogger.error({ err: error, playerId, itemId, price }, 'Failed to buy item');
    }
  }

  private calculateSellPrice(itemId: string, rarity: number): number {
    // Base prices for different item types
    const basePrices: Record<string, number> = {
      // Fish prices by water type and tier
      'fish_pond_1': 10, 'fish_pond_2': 25, 'fish_pond_3': 50, 'fish_pond_4': 150,
      'fish_river_1': 12, 'fish_river_2': 30, 'fish_river_3': 60, 'fish_river_4': 180,
      'fish_ocean_1': 15, 'fish_ocean_2': 40, 'fish_ocean_3': 80, 'fish_ocean_4': 250,
      'fish_night_1': 20, 'fish_night_2': 45, 'fish_night_3': 90, 'fish_night_4': 300,
      // Poles
      'pole_1': 50, 'pole_2': 200, 'pole_3': 500, 'pole_4': 1500,
      // Lures
      'lure_1': 10, 'lure_2': 30, 'lure_3': 80, 'lure_4': 250,
    };
    
    const basePrice = basePrices[itemId] ?? 10;
    
    // Apply rarity multiplier for fish
    const multiplier = rarity <= 1 ? 1.0 : (rarity === 2 ? 2.0 : 4.0);
    return Math.round(basePrice * multiplier);
  }

  private broadcastPlayersUpdate(): void {
    if (this.onPlayersUpdate) {
      this.onPlayersUpdate(Array.from(this.players.values()));
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

  disconnect() {
    if (this.conn) {
      this.conn.disconnect();
      this.conn = null;
    }
    this.isConnected = false;
    this.players.clear();
    this.inventory.clear();
  }
}
