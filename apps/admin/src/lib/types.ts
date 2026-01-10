// Types matching the bridge/SpacetimeDB schema

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
  equippedPoleId: string | null;
}

export interface InventoryItem {
  id: number;
  playerId: string;
  itemId: string;
  rarity: number;
  quantity: number;
}

export interface Quest {
  id: string;
  title: string;
  description: string;
  questType: "story" | "daily";
  storyline: string | null;
  storyOrder: number | null;
  prerequisiteQuestId: string | null;
  requirements: string;
  rewards: string;
  // Quest giver system
  questGiverType: "npc" | "sign" | null;
  questGiverId: string | null;
}

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

export interface Storyline {
  id: string;
  name: string;
  description: string;
  icon: string | null;
  category: "main" | "side" | "event";
  displayOrder: number;
  unlockConditions: string | null;
  isActive: boolean;
  totalQuests: number;
}

export interface PlayerQuest {
  id: number;
  playerId: string;
  questId: string;
  status: "available" | "active" | "completed";
  progress: string;
  acceptedAt: number | null;
  completedAt: number | null;
}

export type GameEventType =
  | "fish_caught"
  | "item_bought"
  | "item_sold"
  | "session_started"
  | "session_ended"
  | "pole_equipped"
  | "pole_unequipped"
  | "quest_completed";

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
  metadata: string | null;
  createdAt: number;
}

export interface PlayerStats {
  playerId: string;
  totalPlaytimeSeconds: number;
  totalSessions: number;
  totalFishCaught: number;
  totalGoldEarned: number;
  totalGoldSpent: number;
  firstSeenAt: number;
  lastSeenAt: number;
}
