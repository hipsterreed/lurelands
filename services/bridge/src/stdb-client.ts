import { DbConnection, tables, reducers, type EventContext, type SubscriptionEventContext, type ErrorContext } from './generated';
import type { Player, Pond, River, Ocean, SpawnPoint, WorldState, FishCatch } from './types';

// =============================================================================
// SpacetimeDB Client Wrapper (using new spacetimedb SDK 1.4+)
// Following best practices from: https://spacetimedb.com/docs/sdks/typescript
// =============================================================================

export type PlayerUpdateCallback = (players: Player[]) => void;
export type WorldStateCallback = (worldState: WorldState) => void;
export type FishCaughtCallback = (fishCatch: FishCatch) => void;

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

  // Callbacks
  private onPlayersUpdate: PlayerUpdateCallback | null = null;
  private onWorldState: WorldStateCallback | null = null;
  private onFishCaught: FishCaughtCallback | null = null;

  constructor(
    private uri: string,
    private moduleName: string
  ) {}

  setCallbacks(callbacks: {
    onPlayersUpdate?: PlayerUpdateCallback;
    onWorldState?: WorldStateCallback;
    onFishCaught?: FishCaughtCallback;
  }) {
    this.onPlayersUpdate = callbacks.onPlayersUpdate ?? null;
    this.onWorldState = callbacks.onWorldState ?? null;
    this.onFishCaught = callbacks.onFishCaught ?? null;
  }

  async connect(): Promise<boolean> {
    return new Promise((resolve) => {
      try {
        console.log(`[STDB] Connecting to ${this.uri}/${this.moduleName}...`);
        
        // Build connection with optional token for reconnection
        let builder = DbConnection.builder()
          .withUri(this.uri)
          .withModuleName(this.moduleName);
        
        // Use saved token if available (for reconnection with same identity)
        if (this.authToken) {
          console.log('[STDB] Using saved auth token for reconnection');
          builder = builder.withToken(this.authToken);
        }
        
        this.conn = builder
          .onConnect((ctx, identity, token) => {
            console.log('[STDB] Connected!', identity.toHexString());
            this.isConnected = true;
            
            // Save token for future reconnections (best practice from docs)
            this.authToken = token;
            
            // Subscribe to all tables with error handling
            ctx.subscriptionBuilder()
              .onApplied((subCtx: SubscriptionEventContext) => {
                console.log('[STDB] Subscription applied, loading initial state...');
                this.loadInitialState(subCtx);
              })
              .onError((errCtx: ErrorContext) => {
                // Handle subscription errors (best practice from docs)
                console.error('[STDB] Subscription error:', errCtx.event);
              })
              .subscribe([
                'SELECT * FROM spawn_point',
                'SELECT * FROM pond',
                'SELECT * FROM river',
                'SELECT * FROM ocean',
                'SELECT * FROM player',
                'SELECT * FROM fish_catch',
              ]);
            
            resolve(true);
          })
          .onConnectError((ctx: ErrorContext, error) => {
            console.error('[STDB] Connection error:', error);
            this.isConnected = false;
            resolve(false);
          })
          .onDisconnect((ctx) => {
            console.log('[STDB] Disconnected');
            this.isConnected = false;
          })
          .build();

        // Set up table callbacks before any data arrives
        this.setupTableCallbacks();

      } catch (error) {
        console.error('[STDB] Connection failed:', error);
        this.isConnected = false;
        resolve(false);
      }
    });
  }

  private loadInitialState(ctx: SubscriptionEventContext) {
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
    console.log(`[STDB] Loaded ${this.spawnPoints.length} spawn points`);

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
    console.log(`[STDB] Loaded ${this.ponds.length} ponds`);

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
    console.log(`[STDB] Loaded ${this.rivers.length} rivers`);

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
    console.log(`[STDB] Ocean loaded: ${this.ocean ? 'yes' : 'no'}`);

    // Load players
    this.players.clear();
    for (const p of ctx.db.player.iter()) {
      this.players.set(p.id, this.mapPlayer(p));
    }
    console.log(`[STDB] Loaded ${this.players.size} players`);

    // Emit callbacks
    this.emitWorldState();
    this.emitPlayersUpdate();
  }

  private setupTableCallbacks() {
    if (!this.conn) return;

    // Player table callbacks
    this.conn.db.player.onInsert((ctx: EventContext, player) => {
      console.log(`[STDB] Player inserted: ${player.id}`);
      this.players.set(player.id, this.mapPlayer(player));
      this.emitPlayersUpdate();
    });

    this.conn.db.player.onUpdate((ctx: EventContext, oldPlayer, newPlayer) => {
      this.players.set(newPlayer.id, this.mapPlayer(newPlayer));
      this.emitPlayersUpdate();
    });

    this.conn.db.player.onDelete((ctx: EventContext, player) => {
      console.log(`[STDB] Player deleted: ${player.id}`);
      this.players.delete(player.id);
      this.emitPlayersUpdate();
    });

    // Fish catch callback
    this.conn.db.fishCatch.onInsert((ctx: EventContext, fc) => {
      console.log(`[STDB] Fish caught by ${fc.playerId}`);
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
    console.log('[STDB] joinWorld called:', { playerId, name, color });
    
    if (!this.conn || !this.isConnected) {
      console.log('[STDB] Not connected, cannot join world');
      return null;
    }

    try {
      // Call reducer with params object (SDK requirement)
      this.conn.reducers.joinWorld({ playerId, name, color: color >>> 0 });
      console.log('[STDB] joinWorld reducer called');
      
      // Pick a random spawn point
      if (this.spawnPoints.length > 0) {
        const spawn = this.spawnPoints[Math.floor(Math.random() * this.spawnPoints.length)];
        console.log('[STDB] Returning spawn:', spawn.name);
        return { x: spawn.x, y: spawn.y };
      }
      return { x: 1000, y: 1000 };
    } catch (error) {
      console.error('[STDB] Failed to join world:', error);
      return null;
    }
  }

  async leaveWorld(playerId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.leaveWorld({ playerId });
    } catch (error) {
      console.error('[STDB] Failed to leave world:', error);
    }
  }

  private _lastPositionLog = 0;
  
  async updatePosition(playerId: string, x: number, y: number, facingAngle: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.updatePosition({ playerId, x, y, facingAngle });
      
      // Log once per second max
      const now = Date.now();
      if (now - this._lastPositionLog > 1000) {
        console.log('[STDB] Position update:', { playerId: playerId.substring(0, 10), x: x.toFixed(0), y: y.toFixed(0) });
        this._lastPositionLog = now;
      }
    } catch (error) {
      console.error('[STDB] Position update error:', error);
    }
  }

  async startCasting(playerId: string, targetX: number, targetY: number): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.startCasting({ playerId, targetX, targetY });
    } catch (error) {
      console.error('[STDB] Failed to start casting:', error);
    }
  }

  async stopCasting(playerId: string): Promise<void> {
    if (!this.conn || !this.isConnected) return;
    try {
      this.conn.reducers.stopCasting({ playerId });
    } catch (error) {
      console.error('[STDB] Failed to stop casting:', error);
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

  getIsConnected(): boolean {
    return this.isConnected;
  }

  disconnect() {
    if (this.conn) {
      this.conn.disconnect();
      this.conn = null;
    }
    this.isConnected = false;
    this.players.clear();
  }
}
