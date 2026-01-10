// =============================================================================
// Types shared between bridge and Flutter client
// =============================================================================

// --- World Data Types ---

export interface SpawnPoint {
  id: string;
  x: number;
  y: number;
  name: string;
}

export interface Pond {
  id: string;
  x: number;
  y: number;
  radius: number;
}

export interface River {
  id: string;
  x: number;
  y: number;
  width: number;
  length: number;
  rotation: number;
}

export interface Ocean {
  id: string;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface WorldState {
  spawnPoints: SpawnPoint[];
  ponds: Pond[];
  rivers: River[];
  ocean: Ocean | null;
}

// --- Player Types ---

export interface Player {
  id: string;
  name: string;
  x: number;
  y: number;
  facingAngle: number;
  isCasting: boolean;
  castTargetX: number | null;
  castTargetY: number | null;
  color: number;
  isOnline: boolean;
  gold: number;
  equippedPoleId: string | null;  // Currently equipped fishing pole item ID
}

export interface FishCatch {
  id: number;
  fishId: string;
  playerId: string;
  fishType: string;
  size: number;
  rarity: string;
  waterBodyId: string;
  released: boolean;
}

export interface InventoryItem {
  id: number;
  playerId: string;
  itemId: string;
  rarity: number;  // 1-3 for fish stars, 0 for non-fish
  quantity: number;
}

// =============================================================================
// Session & Event Tracking Types
// =============================================================================

export interface PlayerSession {
  id: number;
  playerId: string;
  startedAt: number;  // Unix timestamp (microseconds)
  endedAt: number | null;  // Unix timestamp (microseconds)
  durationSeconds: number;
  isActive: boolean;
}

export interface PlayerStats {
  playerId: string;
  totalPlaytimeSeconds: number;
  totalSessions: number;
  totalFishCaught: number;
  totalGoldEarned: number;
  totalGoldSpent: number;
  firstSeenAt: number;  // Unix timestamp (microseconds)
  lastSeenAt: number;   // Unix timestamp (microseconds)
  // Level system
  level: number;
  xp: number;
  xpToNextLevel: number;
}

export type GameEventType = 
  | 'fish_caught'
  | 'item_bought'
  | 'item_sold'
  | 'session_started'
  | 'session_ended'
  | 'pole_equipped'
  | 'pole_unequipped'
  | 'quest_completed';

// =============================================================================
// Quest Types
// =============================================================================

export interface Quest {
  id: string;
  title: string;
  description: string;
  questType: 'story' | 'daily';
  storyline: string | null;
  storyOrder: number | null;
  prerequisiteQuestId: string | null;
  requirements: string;  // JSON string
  rewards: string;       // JSON string
  // Quest giver system
  questGiverType: 'npc' | 'sign' | null;  // "npc", "sign", or null (any sign)
  questGiverId: string | null;            // NPC ID or Sign ID
}

export interface PlayerQuest {
  id: number;
  playerId: string;
  questId: string;
  status: 'available' | 'active' | 'completed';
  progress: string;  // JSON string
  acceptedAt: number | null;   // Unix timestamp (microseconds)
  completedAt: number | null;  // Unix timestamp (microseconds)
}

// =============================================================================
// Storyline Types
// =============================================================================

export interface Storyline {
  id: string;
  name: string;
  description: string;
  icon: string | null;
  category: 'main' | 'side' | 'event';
  displayOrder: number;
  unlockConditions: string | null;  // JSON string
  isActive: boolean;
  totalQuests: number;
}

export interface PlayerStoryline {
  id: number;
  playerId: string;
  storylineId: string;
  status: 'locked' | 'unlocked' | 'in_progress' | 'completed';
  questsCompleted: number;
  currentQuestId: string | null;
  unlockedAt: number | null;   // Unix timestamp (microseconds)
  completedAt: number | null;  // Unix timestamp (microseconds)
}

// =============================================================================
// NPC Types
// =============================================================================

export interface Npc {
  id: string;
  name: string;
  title: string | null;
  description: string | null;
  locationX: number | null;
  locationY: number | null;
  spriteId: string | null;
  canGiveQuests: boolean;
  canTrade: boolean;
  isActive: boolean;
}

export interface PlayerNpcInteraction {
  id: number;
  playerId: string;
  npcId: string;
  hasTalked: boolean;
  hasTraded: boolean;
  talkCount: number;
  reputation: number;  // -100 to 100
  firstInteractionAt: number;  // Unix timestamp (microseconds)
  lastInteractionAt: number;   // Unix timestamp (microseconds)
}

// =============================================================================
// Item Definition Types
// =============================================================================

export interface ItemDefinition {
  id: string;
  name: string;
  category: 'fish' | 'pole' | 'lure';
  waterType: 'pond' | 'river' | 'ocean' | 'night' | null;
  tier: number;
  buyPrice: number;
  sellPrice: number;
  stackSize: number;
  spriteId: string;
  description: string | null;
  isActive: boolean;
  rarityMultipliers: string | null;  // JSON string: {"2": 2.0, "3": 4.0}
  metadata: string | null;           // JSON string for extensibility
}

export interface GameEvent {
  id: number;
  playerId: string;
  sessionId: number | null;
  eventType: GameEventType;
  itemId: string | null;
  quantity: number | null;
  goldAmount: number | null;
  rarity: number | null;
  waterBodyId: string | null;
  metadata: string | null;  // JSON string for extensibility
  createdAt: number;  // Unix timestamp (microseconds)
}

// =============================================================================
// Client → Bridge Messages
// =============================================================================

export type ClientMessage =
  | { type: 'join'; playerId: string; name: string; color: number }
  | { type: 'move'; x: number; y: number; angle: number }
  | { type: 'cast'; targetX: number; targetY: number }
  | { type: 'reel' }
  | { type: 'leave' }
  | { type: 'update_name'; playerId: string; name: string }
  | { type: 'fetch_player'; playerId: string }
  | { type: 'catch_fish'; itemId: string; rarity: number; waterBodyId: string }
  | { type: 'get_inventory' }
  | { type: 'sell_item'; itemId: string; rarity: number; quantity: number }
  | { type: 'buy_item'; itemId: string; price: number }
  | { type: 'equip_pole'; poleItemId: string }
  | { type: 'unequip_pole' }
  | { type: 'set_gold'; amount: number }
  // Quest messages
  | { type: 'get_quests' }
  | { type: 'accept_quest'; questId: string }
  | { type: 'complete_quest'; questId: string }
  | { type: 'reset_quests' }
  // NPC interaction messages
  | { type: 'npc_talk'; npcId: string }
  | { type: 'npc_trade'; npcId: string }
  // Storyline/NPC data requests
  | { type: 'get_storylines' }
  | { type: 'get_npcs' };

// =============================================================================
// Bridge → Client Messages
// =============================================================================

export type ServerMessage =
  | { type: 'connected'; playerId: string }
  | { type: 'world_state'; data: WorldState }
  | { type: 'spawn'; x: number; y: number }
  | { type: 'players'; players: Player[] }
  | { type: 'player_joined'; player: Player }
  | { type: 'player_left'; playerId: string }
  | { type: 'player_updated'; player: Player }
  | { type: 'fish_caught'; catch: FishCatch }
  | { type: 'player_data'; player: Player | null }
  | { type: 'inventory'; items: InventoryItem[] }
  | { type: 'inventory_updated'; item: InventoryItem }
  | { type: 'error'; message: string }
  // Quest messages
  | { type: 'quests'; quests: Quest[]; playerQuests: PlayerQuest[] }
  | { type: 'quest_updated'; playerQuest: PlayerQuest }
  // Player stats (with level info)
  | { type: 'player_stats'; stats: PlayerStats }
  | { type: 'level_up'; playerId: string; newLevel: number; xp: number; xpToNextLevel: number }
  // Storyline messages
  | { type: 'storylines'; storylines: Storyline[]; playerStorylines: PlayerStoryline[] }
  | { type: 'storyline_updated'; playerStoryline: PlayerStoryline }
  // NPC messages
  | { type: 'npcs'; npcs: Npc[]; playerNpcInteractions: PlayerNpcInteraction[] }
  | { type: 'npc_interaction_updated'; interaction: PlayerNpcInteraction };

