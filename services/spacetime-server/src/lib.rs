//! Lurelands SpacetimeDB Server Module
//!
//! This module handles real-time multiplayer synchronization for the Lurelands game.
//! Players connect via WebSocket and their state is synchronized across all clients.

use spacetimedb::{ReducerContext, Table, Timestamp};

/// Player table - tracks all connected players in the game world
#[derive(Clone)]
#[spacetimedb::table(name = player, public)]
pub struct Player {
    /// Unique player identifier (from authentication)
    #[primary_key]
    pub id: String,
    
    /// Player display name
    pub name: String,
    
    /// X position in the game world
    pub x: f32,
    
    /// Y position in the game world
    pub y: f32,
    
    /// Angle the player is facing (radians)
    pub facing_angle: f32,
    
    /// Whether the player is currently casting their line
    pub is_casting: bool,
    
    /// X position of the cast target (if casting)
    pub cast_target_x: Option<f32>,
    
    /// Y position of the cast target (if casting)
    pub cast_target_y: Option<f32>,
    
    /// Player color for customization (ARGB)
    pub color: u32,
    
    /// Whether the player is currently online and in the world
    pub is_online: bool,
    
    /// Player's gold currency
    #[sats(default)]
    pub gold: u32,
    
    /// Currently equipped fishing pole item ID (e.g., "pole_1", "pole_2", etc.)
    /// None means no pole equipped (uses default tier 1)
    #[sats(default)]
    pub equipped_pole_id: Option<String>,
    
    /// Timestamp of last update
    pub last_updated: Timestamp,
}

/// Fish catch log - tracks all fish that have been caught
#[spacetimedb::table(name = fish_catch, public)]
pub struct FishCatch {
    /// Unique identifier for this catch event
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    
    /// The fish's unique identifier (for tracking across catches)
    pub fish_id: String,
    
    /// Player who caught this fish
    pub player_id: String,
    
    /// Type/species of fish
    pub fish_type: String,
    
    /// Size of the fish (in game units)
    pub size: f32,
    
    /// Rarity tier (common, uncommon, rare, epic, legendary)
    pub rarity: String,
    
    /// Which water body it was caught in
    pub water_body_id: String,
    
    /// Whether the fish was released back
    pub released: bool,
    
    /// When the fish was caught
    pub caught_at: Timestamp,
}

/// Player inventory - tracks items owned by players (stacked by item_id + rarity)
#[derive(Clone)]
#[spacetimedb::table(name = inventory, public)]
pub struct Inventory {
    /// Unique row identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    
    /// Player who owns this inventory entry
    pub player_id: String,
    
    /// Item identifier (e.g., "fish_ocean_1", "pole_2")
    pub item_id: String,
    
    /// Star rarity for fish (1-3), 0 for non-fish items
    pub rarity: u8,
    
    /// Quantity of this item stack
    pub quantity: u32,
}

/// Spawn point data - defines where players can spawn in the world
#[derive(Clone)]
#[spacetimedb::table(name = spawn_point, public)]
pub struct SpawnPoint {
    #[primary_key]
    pub id: String,
    
    /// X position in the game world
    pub x: f32,
    
    /// Y position in the game world
    pub y: f32,
    
    /// Human-readable name for this spawn point
    pub name: String,
}

/// Pond data - circular fishing ponds
#[derive(Clone)]
#[spacetimedb::table(name = pond, public)]
pub struct Pond {
    #[primary_key]
    pub id: String,
    
    /// Center X position
    pub x: f32,
    
    /// Center Y position
    pub y: f32,
    
    /// Radius of the pond
    pub radius: f32,
}

/// River data - rectangular river segments
#[derive(Clone)]
#[spacetimedb::table(name = river, public)]
pub struct River {
    #[primary_key]
    pub id: String,
    
    /// Center X position
    pub x: f32,
    
    /// Center Y position
    pub y: f32,
    
    /// Width of the river (perpendicular to flow)
    pub width: f32,
    
    /// Length of the river segment
    pub length: f32,
    
    /// Rotation in radians (0 = horizontal)
    pub rotation: f32,
}

/// Ocean data - large rectangular water body (typically on map edge)
#[spacetimedb::table(name = ocean, public)]
pub struct Ocean {
    #[primary_key]
    pub id: String,
    
    /// Top-left X position
    pub x: f32,
    
    /// Top-left Y position
    pub y: f32,
    
    /// Width of the ocean area
    pub width: f32,
    
    /// Height of the ocean area
    pub height: f32,
}

// =============================================================================
// QUEST SYSTEM
// =============================================================================

/// Quest definition table - stores all available quests
#[derive(Clone)]
#[spacetimedb::table(name = quest, public)]
pub struct Quest {
    /// Unique quest identifier (e.g., "guild_1", "ocean_1", "daily_haul")
    #[primary_key]
    pub id: String,

    /// Display title of the quest
    pub title: String,

    /// Flavor text / description
    pub description: String,

    /// Quest type: "story" or "daily"
    pub quest_type: String,

    /// Storyline group (e.g., "fishermans_guild", "ocean_mysteries")
    /// None for daily quests which have no storyline
    pub storyline: Option<String>,

    /// Order within the storyline (1, 2, 3...)
    /// None for daily quests
    pub story_order: Option<u32>,

    /// Quest ID that must be completed before this one is available
    /// None if this is the first quest in a storyline or a daily
    pub prerequisite_quest_id: Option<String>,

    /// Requirements as JSON string
    /// New format: {"objectives": {...}, "unlock_conditions": {...}}
    /// Legacy format (still supported): {"fish": {...}, "total_fish": N, "min_rarity": N}
    pub requirements: String,

    /// Rewards as JSON string
    /// Format: {"gold": 100, "items": [{"item_id": "pole_2", "quantity": 1}]}
    pub rewards: String,

    // === QUEST GIVER SYSTEM ===

    /// Type of quest giver: "npc", "sign", or None (available at any sign with matching storyline)
    #[sats(default)]
    pub quest_giver_type: Option<String>,

    /// ID of the quest giver (NPC ID or Sign ID)
    #[sats(default)]
    pub quest_giver_id: Option<String>,
}

/// Player quest progress table - tracks each player's quest state
#[derive(Clone)]
#[spacetimedb::table(name = player_quest, public)]
pub struct PlayerQuest {
    /// Unique row identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    
    /// Player who owns this quest progress
    pub player_id: String,
    
    /// Reference to Quest.id
    pub quest_id: String,
    
    /// Quest status: "available", "active", "completed"
    pub status: String,
    
    /// Progress as JSON string tracking items collected
    /// Format: {"fish_pond_1": 2, "fish_river_1": 1}
    pub progress: String,
    
    /// When the quest was accepted (None if not yet accepted)
    pub accepted_at: Option<Timestamp>,
    
    /// When the quest was completed (None if not yet completed)
    pub completed_at: Option<Timestamp>,
}

// =============================================================================
// STORYLINE SYSTEM
// =============================================================================

/// Storyline definition - groups quests into narrative arcs
#[derive(Clone)]
#[spacetimedb::table(name = storyline, public)]
pub struct Storyline {
    /// Unique storyline identifier (e.g., "fishermans_guild", "ocean_mysteries")
    #[primary_key]
    pub id: String,

    /// Display name for the storyline
    pub name: String,

    /// Description of the storyline
    pub description: String,

    /// Icon identifier for UI display
    pub icon: Option<String>,

    /// Category: "main", "side", "event"
    pub category: String,

    /// Display order in UI (lower = first)
    pub display_order: u32,

    /// Unlock conditions as JSON string (same format as quest unlock_conditions)
    /// Format: {"level": 5} or null for always available
    pub unlock_conditions: Option<String>,

    /// Whether this storyline is currently active (for seasonal/event content)
    pub is_active: bool,

    /// Total number of quests in this storyline (cached for progress display)
    pub total_quests: u32,
}

/// Player storyline progress - tracks a player's progress through a storyline
#[derive(Clone)]
#[spacetimedb::table(name = player_storyline, public)]
pub struct PlayerStoryline {
    /// Unique row identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,

    /// Player who owns this progress
    pub player_id: String,

    /// Reference to Storyline.id
    pub storyline_id: String,

    /// Progress status: "locked", "unlocked", "in_progress", "completed"
    pub status: String,

    /// Number of quests completed in this storyline
    pub quests_completed: u32,

    /// ID of the current active quest in this storyline
    pub current_quest_id: Option<String>,

    /// When the storyline was unlocked
    pub unlocked_at: Option<Timestamp>,

    /// When all quests were completed
    pub completed_at: Option<Timestamp>,
}

// =============================================================================
// NPC SYSTEM
// =============================================================================

/// NPC definition - non-player characters that can give quests and interact with players
#[derive(Clone)]
#[spacetimedb::table(name = npc, public)]
pub struct Npc {
    /// Unique NPC identifier (e.g., "guild_master", "dock_worker")
    #[primary_key]
    pub id: String,

    /// Display name for the NPC
    pub name: String,

    /// Title/role (e.g., "Fisherman's Guild Leader")
    pub title: Option<String>,

    /// Description text for NPC dialog
    pub description: Option<String>,

    /// X position in the game world (for spawning)
    pub location_x: Option<f32>,

    /// Y position in the game world (for spawning)
    pub location_y: Option<f32>,

    /// Sprite/asset identifier for rendering
    pub sprite_id: Option<String>,

    /// Whether this NPC can give quests
    pub can_give_quests: bool,

    /// Whether this NPC can trade with players
    pub can_trade: bool,

    /// Whether this NPC is currently active in the world
    pub is_active: bool,
}

/// Player-NPC interaction tracking - for unlock conditions and relationship tracking
#[derive(Clone)]
#[spacetimedb::table(name = player_npc_interaction, public)]
pub struct PlayerNpcInteraction {
    /// Unique row identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,

    /// Player who interacted with the NPC
    pub player_id: String,

    /// NPC that was interacted with
    pub npc_id: String,

    /// Whether the player has ever talked to this NPC
    pub has_talked: bool,

    /// Whether the player has ever traded with this NPC
    pub has_traded: bool,

    /// Number of times player has talked to this NPC (for reputation)
    pub talk_count: u32,

    /// Reputation with this NPC (-100 to 100, 0 = neutral)
    pub reputation: i32,

    /// When the player first interacted with this NPC
    pub first_interaction_at: Timestamp,

    /// When the player last interacted with this NPC
    pub last_interaction_at: Timestamp,
}

// =============================================================================
// SESSION & EVENT TRACKING
// =============================================================================

/// Player session - tracks individual play sessions
#[spacetimedb::table(name = player_session, public)]
pub struct PlayerSession {
    /// Unique session identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    
    /// Player who started this session
    pub player_id: String,
    
    /// When the session started
    pub started_at: Timestamp,
    
    /// When the session ended (None if still active)
    pub ended_at: Option<Timestamp>,
    
    /// Duration in seconds (calculated when session ends)
    pub duration_seconds: u64,
    
    /// Whether this session is still active
    pub is_active: bool,
}

/// Player stats - aggregated statistics per player
#[spacetimedb::table(name = player_stats, public)]
pub struct PlayerStats {
    /// Player identifier (matches Player.id)
    #[primary_key]
    pub player_id: String,

    /// Total playtime in seconds across all sessions
    pub total_playtime_seconds: u64,

    /// Total number of sessions
    pub total_sessions: u32,

    /// Total fish caught (all time)
    pub total_fish_caught: u32,

    /// Total gold earned (all time)
    pub total_gold_earned: u64,

    /// Total gold spent (all time)
    pub total_gold_spent: u64,

    /// When this player was first seen
    pub first_seen_at: Timestamp,

    /// When this player was last seen
    pub last_seen_at: Timestamp,

    // === LEVEL SYSTEM ===

    /// Current player level (starts at 1)
    #[sats(default)]
    pub level: u32,

    /// Current XP accumulated
    #[sats(default)]
    pub xp: u64,

    /// XP required to reach next level (cached for client)
    #[sats(default)]
    pub xp_to_next_level: u64,
}

/// Event types for game event logging
#[derive(Clone, Debug, PartialEq)]
pub enum GameEventType {
    FishCaught,
    ItemBought,
    ItemSold,
    SessionStarted,
    SessionEnded,
    PoleEquipped,
    PoleUnequipped,
}

impl std::fmt::Display for GameEventType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            GameEventType::FishCaught => write!(f, "fish_caught"),
            GameEventType::ItemBought => write!(f, "item_bought"),
            GameEventType::ItemSold => write!(f, "item_sold"),
            GameEventType::SessionStarted => write!(f, "session_started"),
            GameEventType::SessionEnded => write!(f, "session_ended"),
            GameEventType::PoleEquipped => write!(f, "pole_equipped"),
            GameEventType::PoleUnequipped => write!(f, "pole_unequipped"),
        }
    }
}

/// Game event log - tracks all significant player actions for analytics
#[spacetimedb::table(name = game_event, public)]
pub struct GameEvent {
    /// Unique event identifier
    #[primary_key]
    #[auto_inc]
    pub id: u64,
    
    /// Player who triggered this event
    pub player_id: String,
    
    /// Session ID when event occurred (if applicable)
    pub session_id: Option<u64>,
    
    /// Type of event (fish_caught, item_bought, item_sold, etc.)
    pub event_type: String,
    
    /// Item involved in the event (fish_id, pole_id, etc.)
    pub item_id: Option<String>,
    
    /// Quantity of items (for bulk transactions)
    pub quantity: Option<u32>,
    
    /// Gold amount (price for buys/sells, 0 for other events)
    pub gold_amount: Option<u32>,
    
    /// Rarity tier (1-3 for fish, 0 for non-fish items)
    pub rarity: Option<u8>,
    
    /// Water body where event occurred (for fishing events)
    pub water_body_id: Option<String>,
    
    /// Additional metadata as JSON string (for extensibility)
    pub metadata: Option<String>,
    
    /// When the event occurred
    pub created_at: Timestamp,
}

// =============================================================================
// ITEM DEFINITION SYSTEM
// =============================================================================

/// Item definition table - stores all item configurations (database-driven)
/// This replaces hardcoded pricing and allows admin management of items
#[derive(Clone)]
#[spacetimedb::table(name = item_definition, public)]
pub struct ItemDefinition {
    /// Unique item identifier (e.g., "fish_pond_1", "pole_2", "lure_3")
    #[primary_key]
    pub id: String,

    /// Display name (e.g., "Pond Sunfish", "Steel Rod")
    pub name: String,

    /// Item category: "fish", "pole", "lure"
    pub category: String,

    /// Water type for fish: "pond", "river", "ocean", "night", or None for non-fish
    pub water_type: Option<String>,

    /// Tier level (1-4 typically)
    pub tier: u8,

    /// Base buy price (what players pay in shop, 0 = not purchasable)
    pub buy_price: u32,

    /// Base sell price (before rarity multiplier)
    pub sell_price: u32,

    /// Maximum stack size (1 for poles, 5 for fish, 99 for lures)
    pub stack_size: u32,

    /// Sprite identifier for rendering (matches Flutter asset name)
    pub sprite_id: String,

    /// Item description for tooltips
    pub description: Option<String>,

    /// Whether this item is currently available in game
    pub is_active: bool,

    /// Rarity multipliers as JSON: {"2": 2.0, "3": 4.0}
    pub rarity_multipliers: Option<String>,

    /// Additional metadata as JSON (for extensibility)
    pub metadata: Option<String>,
}

// =============================================================================
// ITEM STACKING CONSTANTS
// =============================================================================

/// Maximum stack size for fish items
const MAX_FISH_STACK_SIZE: u32 = 5;

/// Maximum stack size for poles (no stacking)
const MAX_POLE_STACK_SIZE: u32 = 1;

/// Check if an item ID represents a fishing pole
fn is_pole_item(item_id: &str) -> bool {
    item_id.starts_with("pole_")
}

/// Check if an item ID represents a fish
fn is_fish_item(item_id: &str) -> bool {
    item_id.starts_with("fish_")
}

/// Get the maximum stack size for an item type
fn get_max_stack_size(item_id: &str) -> u32 {
    if is_pole_item(item_id) {
        MAX_POLE_STACK_SIZE
    } else if is_fish_item(item_id) {
        MAX_FISH_STACK_SIZE
    } else {
        // Lures and other items can stack freely (or adjust as needed)
        u32::MAX
    }
}

// =============================================================================
// ITEM PRICING (Server-Authoritative)
// =============================================================================

/// Get the base sell price for an item (before rarity multiplier)
fn get_item_base_sell_price(item_id: &str) -> u32 {
    match item_id {
        // Fish prices by water type and tier
        "fish_pond_1" => 10,
        "fish_pond_2" => 25,
        "fish_pond_3" => 50,
        "fish_pond_4" => 150,
        "fish_river_1" => 12,
        "fish_river_2" => 30,
        "fish_river_3" => 60,
        "fish_river_4" => 180,
        "fish_ocean_1" => 15,
        "fish_ocean_2" => 40,
        "fish_ocean_3" => 80,
        "fish_ocean_4" => 250,
        "fish_night_1" => 20,
        "fish_night_2" => 45,
        "fish_night_3" => 90,
        "fish_night_4" => 300,
        // Poles (pole_1 is worthless)
        "pole_1" => 0,
        "pole_2" => 200,
        "pole_3" => 500,
        "pole_4" => 1500,
        // Lures
        "lure_1" => 10,
        "lure_2" => 30,
        "lure_3" => 80,
        "lure_4" => 250,
        // Default
        _ => 5,
    }
}

/// Get the buy price for an item (what players pay in the shop)
fn get_item_buy_price(item_id: &str) -> u32 {
    match item_id {
        // Poles - buy prices
        "pole_1" => 0,   // Free starter pole
        "pole_2" => 200,
        "pole_3" => 500,
        "pole_4" => 1500,
        // Lures
        "lure_1" => 20,
        "lure_2" => 60,
        "lure_3" => 160,
        "lure_4" => 500,
        // Default (shouldn't happen for purchasable items)
        _ => 0,
    }
}

/// Calculate sell price with rarity multiplier
fn calculate_sell_price(item_id: &str, rarity: u8) -> u32 {
    let base_price = get_item_base_sell_price(item_id);
    let multiplier = match rarity {
        0 | 1 => 1.0,  // Common / 1-star
        2 => 2.0,      // 2-star
        3 => 4.0,      // 3-star
        _ => 1.0,
    };
    (base_price as f32 * multiplier).round() as u32
}

// =============================================================================
// LEVEL SYSTEM CONSTANTS
// =============================================================================

/// Base XP for level calculation
const XP_BASE: f64 = 100.0;
/// Exponent for level progression curve
const XP_EXPONENT: f64 = 1.5;

/// XP gained per fish caught (base amount)
const XP_PER_FISH_BASE: u64 = 10;
/// XP bonus per fish tier (tier 4 = +40 XP)
const XP_PER_FISH_TIER: u64 = 10;
/// XP bonus per rarity star above 1 (2-star = +5, 3-star = +10)
const XP_PER_RARITY_STAR: u64 = 5;
/// Base XP for completing a quest
const XP_QUEST_BASE: u64 = 50;
/// Bonus XP for story quests
const XP_QUEST_STORY_BONUS: u64 = 100;

/// Calculate XP required to reach a specific level
/// Formula: XP = 100 * level^1.5
fn calculate_xp_for_level(level: u32) -> u64 {
    if level <= 1 {
        return 0;
    }
    (XP_BASE * (level as f64).powf(XP_EXPONENT)).round() as u64
}

/// Calculate XP gained from catching a fish
fn calculate_fish_xp(item_id: &str, rarity: u8) -> u64 {
    // Extract tier from item_id (e.g., "fish_pond_2" -> tier 2)
    let tier: u64 = item_id
        .split('_')
        .last()
        .and_then(|s| s.parse().ok())
        .unwrap_or(1);

    XP_PER_FISH_BASE
        + (tier * XP_PER_FISH_TIER)
        + ((rarity.saturating_sub(1)) as u64 * XP_PER_RARITY_STAR)
}

// =============================================================================
// REDUCERS - Actions that clients can call to modify state
// =============================================================================

/// Called when a player joins the game world
/// Spawns the player at a random spawn point
#[spacetimedb::reducer]
pub fn join_world(ctx: &ReducerContext, player_id: String, name: String, color: u32) {
    // Check if player already exists - if so, mark them as online and preserve their data
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        log::info!("Player {} reconnecting, preserving existing data (name: {})", player_id, player.name);
        player.is_online = true;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        
        // Start a new session for reconnecting player
        start_session(ctx, player_id);
        return;
    }
    
    // Get all spawn points and pick one randomly
    let spawn_points: Vec<SpawnPoint> = ctx.db.spawn_point().iter().collect();
    
    let (spawn_x, spawn_y) = if spawn_points.is_empty() {
        // Fallback to center if no spawn points defined
        log::warn!("No spawn points found, using default center position");
        (1000.0, 1000.0)
    } else {
        // Use player_id hash for pseudo-random spawn point selection
        let hash: usize = player_id.bytes().map(|b| b as usize).sum();
        let index = hash % spawn_points.len();
        let spawn = &spawn_points[index];
        log::info!("Player {} spawning at {} ({}, {})", player_id, spawn.name, spawn.x, spawn.y);
        (spawn.x, spawn.y)
    };
    
    let player = Player {
        id: player_id.clone(),
        name,
        x: spawn_x,
        y: spawn_y,
        facing_angle: 0.0,
        is_casting: false,
        cast_target_x: None,
        cast_target_y: None,
        color,
        is_online: true,
        gold: 0,
        equipped_pole_id: None,
        last_updated: ctx.timestamp,
    };
    
    ctx.db.player().insert(player);
    log::info!("Player {} joined the world at ({}, {}) with 0g", player_id, spawn_x, spawn_y);
    
    // Start a session for new player
    start_session(ctx, player_id);
}

/// Called when a player explicitly leaves the game world (e.g., logout)
/// Marks the player as offline but keeps them in the database for reconnection
#[spacetimedb::reducer]
pub fn leave_world(ctx: &ReducerContext, player_id: String) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.is_online = false;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::info!("Player {} left the world (marked as offline)", player_id);
        
        // End the current session
        end_session(ctx, player_id);
    }
}

/// Called when a player moves to update their position
#[spacetimedb::reducer]
pub fn update_position(ctx: &ReducerContext, player_id: String, x: f32, y: f32, facing_angle: f32) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.x = x;
        player.y = y;
        player.facing_angle = facing_angle;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
    }
}

/// Called when a player starts casting their fishing line
#[spacetimedb::reducer]
pub fn start_casting(ctx: &ReducerContext, player_id: String, target_x: f32, target_y: f32) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.is_casting = true;
        player.cast_target_x = Some(target_x);
        player.cast_target_y = Some(target_y);
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::debug!("Player {} started casting at ({}, {})", player_id, target_x, target_y);
    }
}

/// Called when a player reels in their line
#[spacetimedb::reducer]
pub fn stop_casting(ctx: &ReducerContext, player_id: String) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.is_casting = false;
        player.cast_target_x = None;
        player.cast_target_y = None;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::debug!("Player {} stopped casting", player_id);
    }
}

/// Called when a player catches a fish
#[spacetimedb::reducer]
pub fn catch_fish(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    fish_type: String,
    size: f32,
    rarity: u8,
    water_body_id: String,
) {
    // Log the catch event to FishCatch table (legacy)
    let catch = FishCatch {
        id: 0, // auto-incremented
        fish_id: item_id.clone(),
        player_id: player_id.clone(),
        fish_type: fish_type.clone(),
        size,
        rarity: format!("{}star", rarity),
        water_body_id: water_body_id.clone(),
        released: false,
        caught_at: ctx.timestamp,
    };
    
    ctx.db.fish_catch().insert(catch);
    log::info!("Player {} caught fish {} ({}star)", player_id, item_id, rarity);
    
    // Add to inventory with stack size limit
    let max_stack = get_max_stack_size(&item_id);
    
    // Find an existing stack that isn't full
    let existing = ctx.db.inventory().iter().find(|inv| {
        inv.player_id == player_id && inv.item_id == item_id && inv.rarity == rarity && inv.quantity < max_stack
    });
    
    if let Some(mut inv) = existing {
        inv.quantity += 1;
        ctx.db.inventory().id().update(inv);
    } else {
        // Create new stack (either no existing stack or all stacks are full)
        let inv = Inventory {
            id: 0,
            player_id: player_id.clone(),
            item_id: item_id.clone(),
            rarity,
            quantity: 1,
        };
        ctx.db.inventory().insert(inv);
    }
    
    // Log the event to GameEvent table
    log_event_internal(
        ctx,
        player_id.clone(),
        "fish_caught".to_string(),
        Some(item_id.clone()),
        Some(1),
        None,
        Some(rarity),
        Some(water_body_id),
        Some(format!("{{\"fish_type\":\"{}\",\"size\":{}}}", fish_type, size)),
    );
    
    // Update player stats
    if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
        stats.total_fish_caught += 1;
        ctx.db.player_stats().player_id().update(stats);
    }

    // Grant XP for catching fish
    let fish_xp = calculate_fish_xp(&item_id, rarity);
    add_xp_internal(ctx, &player_id, fish_xp, "fish_caught");

    // Update quest progress for any active quests
    update_quest_progress_for_fish(ctx, &player_id, &item_id, rarity);
}

/// Called when a player releases a caught fish
#[spacetimedb::reducer]
pub fn release_fish(ctx: &ReducerContext, catch_id: u64) {
    if let Some(mut catch) = ctx.db.fish_catch().id().find(&catch_id) {
        catch.released = true;
        ctx.db.fish_catch().id().update(catch);
        log::info!("Fish from catch {} was released", catch_id);
    }
}

/// Add an item to a player's inventory (creates new stack or increments existing)
/// Respects stack size limits: poles don't stack, fish max at 5
#[spacetimedb::reducer]
pub fn add_to_inventory(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    rarity: u8,
    quantity: u32,
) {
    let max_stack = get_max_stack_size(&item_id);
    let mut remaining = quantity;
    
    // First, try to fill existing non-full stacks
    while remaining > 0 {
        // Find an existing stack that isn't full
        let existing = ctx.db.inventory().iter().find(|inv| {
            inv.player_id == player_id && inv.item_id == item_id && inv.rarity == rarity && inv.quantity < max_stack
        });
        
        if let Some(mut inv) = existing {
            // Calculate how much we can add to this stack
            let space_available = max_stack - inv.quantity;
            let to_add = remaining.min(space_available);
            
            inv.quantity += to_add;
            remaining -= to_add;
            let new_quantity = inv.quantity;
            ctx.db.inventory().id().update(inv);
            log::info!(
                "Updated inventory for player {}: {} x{} (rarity {})",
                player_id, item_id, new_quantity, rarity
            );
        } else {
            // No existing stack with space, create new stacks
            break;
        }
    }
    
    // Create new stacks for remaining items
    while remaining > 0 {
        let stack_size = remaining.min(max_stack);
        let inv = Inventory {
            id: 0, // auto-incremented
            player_id: player_id.clone(),
            item_id: item_id.clone(),
            rarity,
            quantity: stack_size,
        };
        ctx.db.inventory().insert(inv);
        remaining -= stack_size;
        log::info!(
            "Added to inventory for player {}: {} x{} (rarity {})",
            player_id, item_id, stack_size, rarity
        );
    }
}

/// Get a player's full inventory (for initial load)
/// Note: Clients typically use subscriptions, but this can be used for one-time queries
#[spacetimedb::reducer]
pub fn get_player_inventory(ctx: &ReducerContext, player_id: String) {
    // This reducer doesn't return data directly - clients subscribe to the inventory table
    // and filter by player_id. This is just for logging/debugging.
    let count = ctx.db.inventory().iter().filter(|inv| inv.player_id == player_id).count();
    log::info!("Player {} has {} inventory stacks", player_id, count);
}

/// Remove items from a player's inventory (for selling/using)
/// Handles removal across multiple stacks when quantity exceeds a single stack
#[spacetimedb::reducer]
pub fn remove_from_inventory(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    rarity: u8,
    quantity: u32,
) {
    if quantity == 0 {
        return;
    }

    // Find all matching inventory stacks
    let matching_stacks: Vec<Inventory> = ctx.db.inventory().iter()
        .filter(|inv| inv.player_id == player_id && inv.item_id == item_id && inv.rarity == rarity)
        .collect();
    
    if matching_stacks.is_empty() {
        log::warn!(
            "No inventory stack found for player {} item {} (rarity {})",
            player_id, item_id, rarity
        );
        return;
    }

    // Calculate total owned
    let total_owned: u32 = matching_stacks.iter().map(|inv| inv.quantity).sum();
    
    if total_owned < quantity {
        log::warn!(
            "Player {} only has {} of {} (rarity {}) but tried to remove {}",
            player_id, total_owned, item_id, rarity, quantity
        );
        return;
    }

    // Remove items across stacks
    let mut remaining = quantity;
    for stack in matching_stacks {
        if remaining == 0 {
            break;
        }
        
        let to_remove = remaining.min(stack.quantity);
        
        if stack.quantity <= to_remove {
            // Remove entire stack
            ctx.db.inventory().id().delete(&stack.id);
            log::info!(
                "Removed entire stack from inventory for player {}: {} (rarity {})",
                player_id, item_id, rarity
            );
        } else {
            // Reduce quantity
            let mut updated_stack = stack.clone();
            updated_stack.quantity -= to_remove;
            let new_quantity = updated_stack.quantity;
            ctx.db.inventory().id().update(updated_stack);
            log::info!(
                "Removed {} from inventory for player {}: {} x{} (rarity {})",
                to_remove, player_id, item_id, new_quantity, rarity
            );
        }
        
        remaining -= to_remove;
    }

    log::info!(
        "Successfully removed {} of {} (rarity {}) from player {}",
        quantity, item_id, rarity, player_id
    );
}

/// Called when a player updates their display name
/// If the player doesn't exist, creates them with a default spawn position
#[spacetimedb::reducer]
pub fn update_player_name(ctx: &ReducerContext, player_id: String, name: String) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        // Player exists, just update the name
        player.name = name.clone();
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::info!("Player {} updated name to: {}", player_id, name);
    } else {
        // Player doesn't exist, create them with default position
        // Get spawn points and pick one based on player_id hash (consistent spawn)
        let spawn_points: Vec<SpawnPoint> = ctx.db.spawn_point().iter().collect();
        
        let (spawn_x, spawn_y) = if spawn_points.is_empty() {
            // Fallback to center if no spawn points defined
            (1000.0, 1000.0)
        } else {
            // Use player_id hash for pseudo-random spawn point selection (consistent)
            let hash: usize = player_id.bytes().map(|b| b as usize).sum();
            let index = hash % spawn_points.len();
            let spawn = &spawn_points[index];
            (spawn.x, spawn.y)
        };
        
        let player = Player {
            id: player_id.clone(),
            name: name.clone(),
            x: spawn_x,
            y: spawn_y,
            facing_angle: 0.0,
            is_casting: false,
            cast_target_x: None,
            cast_target_y: None,
            color: 0xFFE74C3C, // Default red color
            is_online: false, // Created via name update, not yet in world
            gold: 0,
            equipped_pole_id: None,
            last_updated: ctx.timestamp,
        };
        
        ctx.db.player().insert(player);
        log::info!("Player {} created with name: {} at ({}, {})", player_id, name, spawn_x, spawn_y);
    }
}

/// Add gold to a player's balance
#[spacetimedb::reducer]
pub fn add_gold(ctx: &ReducerContext, player_id: String, amount: u32) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.gold += amount;
        let new_gold = player.gold;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::info!("Player {} earned {}g (total: {}g)", player_id, amount, new_gold);
        
        // Update player stats
        if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
            stats.total_gold_earned += amount as u64;
            ctx.db.player_stats().player_id().update(stats);
        }
    }
}

/// Spend gold from a player's balance (for purchases)
#[spacetimedb::reducer]
pub fn spend_gold(ctx: &ReducerContext, player_id: String, amount: u32) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        if player.gold >= amount {
            player.gold -= amount;
            let new_gold = player.gold;
            player.last_updated = ctx.timestamp;
            ctx.db.player().id().update(player);
            log::info!("Player {} spent {}g (remaining: {}g)", player_id, amount, new_gold);
            
            // Update player stats
            if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
                stats.total_gold_spent += amount as u64;
                ctx.db.player_stats().player_id().update(stats);
            }
        } else {
            log::warn!("Player {} tried to spend {}g but only has {}g", player_id, amount, player.gold);
        }
    }
}

/// Set a player's gold to a specific amount (debug/admin function)
#[spacetimedb::reducer]
pub fn set_gold(ctx: &ReducerContext, player_id: String, amount: u32) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        let old_gold = player.gold;
        player.gold = amount;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::info!("Player {} gold set from {}g to {}g", player_id, old_gold, amount);
    }
}

/// Atomic sell item reducer - validates ownership, calculates price server-side, removes items, adds gold
#[spacetimedb::reducer]
pub fn sell_item(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    rarity: u8,
    quantity: u32,
) {
    // Validate quantity
    if quantity == 0 {
        log::warn!("Player {} tried to sell 0 items", player_id);
        return;
    }

    // Check if trying to sell an equipped pole
    if is_pole_item(&item_id) {
        if let Some(player) = ctx.db.player().id().find(&player_id) {
            if player.equipped_pole_id.as_deref() == Some(&item_id) {
                log::warn!("Player {} tried to sell equipped pole {}", player_id, item_id);
                return;
            }
        }
    }

    // Find all matching inventory stacks and calculate total owned
    let matching_stacks: Vec<Inventory> = ctx.db.inventory().iter()
        .filter(|inv| inv.player_id == player_id && inv.item_id == item_id && inv.rarity == rarity)
        .collect();
    
    let total_owned: u32 = matching_stacks.iter().map(|inv| inv.quantity).sum();
    
    if total_owned < quantity {
        log::warn!(
            "Player {} tried to sell {} of {} but only owns {}",
            player_id, quantity, item_id, total_owned
        );
        return;
    }

    // Calculate sell price (server-authoritative)
    let unit_price = calculate_sell_price(&item_id, rarity);
    let total_gold = unit_price * quantity;

    // Remove items from inventory (distributed across stacks)
    let mut remaining = quantity;
    for stack in matching_stacks {
        if remaining == 0 {
            break;
        }
        
        let to_remove = remaining.min(stack.quantity);
        
        if stack.quantity <= to_remove {
            // Remove entire stack
            ctx.db.inventory().id().delete(&stack.id);
        } else {
            // Reduce quantity
            let mut updated_stack = stack.clone();
            updated_stack.quantity -= to_remove;
            ctx.db.inventory().id().update(updated_stack);
        }
        
        remaining -= to_remove;
    }

    // Add gold to player
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.gold += total_gold;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        
        // Update player stats
        if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
            stats.total_gold_earned += total_gold as u64;
            ctx.db.player_stats().player_id().update(stats);
        }
    }

    // Log the event
    log_event_internal(
        ctx,
        player_id.clone(),
        "item_sold".to_string(),
        Some(item_id.clone()),
        Some(quantity),
        Some(total_gold),
        Some(rarity),
        None,
        None,
    );

    log::info!(
        "Player {} sold {}x {} (rarity {}) for {}g",
        player_id, quantity, item_id, rarity, total_gold
    );
}

/// Atomic buy item reducer - validates gold, calculates price server-side, deducts gold, adds item
#[spacetimedb::reducer]
pub fn buy_item(ctx: &ReducerContext, player_id: String, item_id: String) {
    // Get buy price (server-authoritative)
    let price = get_item_buy_price(&item_id);
    
    // Validate the item is purchasable
    if price == 0 && item_id != "pole_1" {
        log::warn!("Player {} tried to buy non-purchasable item {}", player_id, item_id);
        return;
    }

    // Check player exists and has enough gold
    let player = match ctx.db.player().id().find(&player_id) {
        Some(p) => p,
        None => {
            log::warn!("Player {} not found for buy_item", player_id);
            return;
        }
    };

    if player.gold < price {
        log::warn!(
            "Player {} cannot afford {} (price: {}, gold: {})",
            player_id, item_id, price, player.gold
        );
        return;
    }

    // Deduct gold
    let mut updated_player = player.clone();
    updated_player.gold -= price;
    updated_player.last_updated = ctx.timestamp;
    ctx.db.player().id().update(updated_player);

    // Update player stats for gold spent
    if price > 0 {
        if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
            stats.total_gold_spent += price as u64;
            ctx.db.player_stats().player_id().update(stats);
        }
    }

    // Add item to inventory using the existing add_to_inventory logic
    let max_stack = get_max_stack_size(&item_id);
    
    // For non-stackable items (poles), always create a new entry
    if max_stack == 1 {
        let inv = Inventory {
            id: 0,
            player_id: player_id.clone(),
            item_id: item_id.clone(),
            rarity: 0, // Purchased items have rarity 0
            quantity: 1,
        };
        ctx.db.inventory().insert(inv);
    } else {
        // For stackable items, try to fill existing stacks first
        let existing = ctx.db.inventory().iter().find(|inv| {
            inv.player_id == player_id && inv.item_id == item_id && inv.rarity == 0 && inv.quantity < max_stack
        });
        
        if let Some(mut inv) = existing {
            inv.quantity += 1;
            ctx.db.inventory().id().update(inv);
        } else {
            let inv = Inventory {
                id: 0,
                player_id: player_id.clone(),
                item_id: item_id.clone(),
                rarity: 0,
                quantity: 1,
            };
            ctx.db.inventory().insert(inv);
        }
    }

    // Log the event
    log_event_internal(
        ctx,
        player_id.clone(),
        "item_bought".to_string(),
        Some(item_id.clone()),
        Some(1),
        Some(price),
        Some(0),
        None,
        None,
    );

    log::info!("Player {} bought {} for {}g", player_id, item_id, price);
}

/// Equip a fishing pole from inventory
/// The pole must exist in the player's inventory to be equipped
#[spacetimedb::reducer]
pub fn equip_pole(ctx: &ReducerContext, player_id: String, pole_item_id: String) {
    // Check if the player owns this pole in their inventory
    let has_pole = ctx.db.inventory().iter().any(|inv| {
        inv.player_id == player_id && inv.item_id == pole_item_id
    });
    
    if !has_pole {
        log::warn!("Player {} tried to equip pole {} but doesn't own it", player_id, pole_item_id);
        return;
    }
    
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        player.equipped_pole_id = Some(pole_item_id.clone());
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
        log::info!("Player {} equipped pole: {}", player_id, pole_item_id);
        
        // Log the equip event
        log_event_internal(
            ctx,
            player_id,
            "pole_equipped".to_string(),
            Some(pole_item_id),
            None, None, None, None, None,
        );
    }
}

/// Unequip the currently equipped fishing pole
/// The pole goes back to regular inventory (it never left, just marked as equipped)
#[spacetimedb::reducer]
pub fn unequip_pole(ctx: &ReducerContext, player_id: String) {
    if let Some(mut player) = ctx.db.player().id().find(&player_id) {
        if let Some(pole_id) = &player.equipped_pole_id {
            log::info!("Player {} unequipped pole: {}", player_id, pole_id);
            
            // Log the unequip event
            log_event_internal(
                ctx,
                player_id.clone(),
                "pole_unequipped".to_string(),
                Some(pole_id.clone()),
                None, None, None, None, None,
            );
        }
        player.equipped_pole_id = None;
        player.last_updated = ctx.timestamp;
        ctx.db.player().id().update(player);
    }
}

// =============================================================================
// QUEST REDUCERS
// =============================================================================

/// Accept a quest - creates a PlayerQuest entry with "active" status
#[spacetimedb::reducer]
pub fn accept_quest(ctx: &ReducerContext, player_id: String, quest_id: String) {
    // Verify the quest exists
    let quest = match ctx.db.quest().id().find(&quest_id) {
        Some(q) => q,
        None => {
            log::warn!("Player {} tried to accept non-existent quest: {}", player_id, quest_id);
            return;
        }
    };
    
    // Check if player already has this quest active or completed
    let existing = ctx.db.player_quest().iter().find(|pq| {
        pq.player_id == player_id && pq.quest_id == quest_id
    });
    
    if let Some(pq) = existing {
        if pq.status == "active" {
            log::warn!("Player {} already has quest {} active", player_id, quest_id);
            return;
        }
        if pq.status == "completed" && quest.quest_type == "story" {
            log::warn!("Player {} already completed story quest {}", player_id, quest_id);
            return;
        }
        // For daily quests, allow re-accepting if completed - delete old entry
        if pq.status == "completed" && quest.quest_type == "daily" {
            ctx.db.player_quest().id().delete(&pq.id);
            log::info!("Player {} re-accepting daily quest {}", player_id, quest_id);
        }
    }
    
    // Check prerequisites for story quests
    if let Some(prereq_id) = &quest.prerequisite_quest_id {
        let prereq_completed = ctx.db.player_quest().iter().any(|pq| {
            pq.player_id == player_id && pq.quest_id == *prereq_id && pq.status == "completed"
        });
        
        if !prereq_completed {
            log::warn!(
                "Player {} cannot accept quest {} - prerequisite {} not completed",
                player_id, quest_id, prereq_id
            );
            return;
        }
    }
    
    // Create the player quest entry
    let player_quest = PlayerQuest {
        id: 0, // auto-incremented
        player_id: player_id.clone(),
        quest_id: quest_id.clone(),
        status: "active".to_string(),
        progress: "{}".to_string(), // Empty JSON object
        accepted_at: Some(ctx.timestamp),
        completed_at: None,
    };
    
    ctx.db.player_quest().insert(player_quest);
    log::info!("Player {} accepted quest: {} ({})", player_id, quest.title, quest_id);
}

/// Complete a quest - validates requirements are met and grants rewards
#[spacetimedb::reducer]
pub fn complete_quest(ctx: &ReducerContext, player_id: String, quest_id: String) {
    // Find the player's quest progress
    let player_quest = match ctx.db.player_quest().iter().find(|pq| {
        pq.player_id == player_id && pq.quest_id == quest_id && pq.status == "active"
    }) {
        Some(pq) => pq,
        None => {
            log::warn!("Player {} has no active quest: {}", player_id, quest_id);
            return;
        }
    };
    
    // Get quest definition
    let quest = match ctx.db.quest().id().find(&quest_id) {
        Some(q) => q,
        None => {
            log::error!("Quest {} not found but player had it active", quest_id);
            return;
        }
    };
    
    // Validate requirements are met
    if !validate_quest_requirements(&quest.requirements, &player_quest.progress) {
        log::warn!(
            "Player {} tried to complete quest {} but requirements not met. Requirements: {}, Progress: {}",
            player_id, quest_id, quest.requirements, player_quest.progress
        );
        return;
    }
    
    // Mark quest as completed
    let mut updated_quest = player_quest.clone();
    updated_quest.status = "completed".to_string();
    updated_quest.completed_at = Some(ctx.timestamp);
    ctx.db.player_quest().id().update(updated_quest);

    // Grant rewards
    grant_quest_rewards(ctx, &player_id, &quest.rewards);

    // Grant XP for completing quest
    let quest_xp = if quest.quest_type == "story" {
        XP_QUEST_BASE + XP_QUEST_STORY_BONUS
    } else {
        XP_QUEST_BASE
    };
    add_xp_internal(ctx, &player_id, quest_xp, "quest_completed");

    log::info!("Player {} completed quest: {} ({})", player_id, quest.title, quest_id);

    // Log the event
    log_event_internal(
        ctx,
        player_id,
        "quest_completed".to_string(),
        Some(quest_id),
        None, None, None, None,
        Some(format!("{{\"rewards\":{}}}", quest.rewards)),
    );
}

/// Internal: Validate that quest requirements are met based on progress
fn validate_quest_requirements(requirements_json: &str, progress_json: &str) -> bool {
    // Parse requirements - expected format: {"fish": {"fish_pond_1": 2}, "min_rarity": 1, "total_fish": 5}
    // Parse progress - expected format: {"fish_pond_1": 2, "fish_river_1": 1, "total": 3, "max_rarity": 2}
    
    // Simple JSON parsing without external crate
    // Requirements can have:
    // - "fish": {"item_id": count} - specific fish counts
    // - "total_fish": N - total fish of any type
    // - "min_rarity": N - at least one fish with this rarity or higher
    
    // For now, use a simple approach: check if all required fish counts are met
    // This is a simplified implementation - a real one would use serde_json
    
    // Extract fish requirements
    if requirements_json.contains("\"fish\"") {
        // Parse the fish requirements
        if let Some(fish_start) = requirements_json.find("\"fish\"") {
            if let Some(obj_start) = requirements_json[fish_start..].find('{') {
                let remaining = &requirements_json[fish_start + obj_start..];
                if let Some(obj_end) = remaining.find('}') {
                    let fish_obj = &remaining[1..obj_end]; // Content inside {}
                    
                    // Parse each fish requirement
                    for part in fish_obj.split(',') {
                        let part = part.trim();
                        if part.is_empty() {
                            continue;
                        }
                        
                        // Parse "fish_id": count
                        if let Some(colon_pos) = part.find(':') {
                            let fish_id = part[..colon_pos].trim().trim_matches('"');
                            let required_count: u32 = part[colon_pos + 1..].trim().parse().unwrap_or(0);
                            
                            // Check progress for this fish
                            let progress_count = get_progress_count(progress_json, fish_id);
                            if progress_count < required_count {
                                return false;
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Check total_fish requirement
    if let Some(total_req) = extract_json_number(requirements_json, "total_fish") {
        let total_progress = get_progress_count(progress_json, "total");
        if total_progress < total_req {
            return false;
        }
    }
    
    // Check min_rarity requirement
    if let Some(min_rarity) = extract_json_number(requirements_json, "min_rarity") {
        let max_caught_rarity = get_progress_count(progress_json, "max_rarity");
        if max_caught_rarity < min_rarity {
            return false;
        }
    }
    
    true
}

/// Helper: Extract a number value from JSON by key
fn extract_json_number(json: &str, key: &str) -> Option<u32> {
    let search_key = format!("\"{}\"", key);
    if let Some(key_pos) = json.find(&search_key) {
        let after_key = &json[key_pos + search_key.len()..];
        if let Some(colon_pos) = after_key.find(':') {
            let after_colon = after_key[colon_pos + 1..].trim_start();
            // Find the end of the number (next non-digit character)
            let num_end = after_colon.find(|c: char| !c.is_ascii_digit()).unwrap_or(after_colon.len());
            if num_end > 0 {
                return after_colon[..num_end].parse().ok();
            }
        }
    }
    None
}

/// Helper: Get a progress count from the progress JSON
fn get_progress_count(progress_json: &str, key: &str) -> u32 {
    extract_json_number(progress_json, key).unwrap_or(0)
}

/// Internal: Grant rewards to a player based on rewards JSON
fn grant_quest_rewards(ctx: &ReducerContext, player_id: &str, rewards_json: &str) {
    // Parse rewards - expected format: {"gold": 100, "items": [{"item_id": "pole_2", "quantity": 1}]}
    
    // Grant gold
    if let Some(gold_amount) = extract_json_number(rewards_json, "gold") {
        if let Some(mut player) = ctx.db.player().id().find(&player_id.to_string()) {
            player.gold += gold_amount;
            player.last_updated = ctx.timestamp;
            ctx.db.player().id().update(player);
            log::info!("Granted {} gold to player {} from quest", gold_amount, player_id);
        }
    }
    
    // Grant items - look for items array
    if rewards_json.contains("\"items\"") {
        // Find items array
        if let Some(items_start) = rewards_json.find("\"items\"") {
            if let Some(arr_start) = rewards_json[items_start..].find('[') {
                let remaining = &rewards_json[items_start + arr_start..];
                if let Some(arr_end) = remaining.find(']') {
                    let items_content = &remaining[1..arr_end];
                    
                    // Parse each item object
                    // Simple approach: find each {...} block
                    let mut depth = 0;
                    let mut item_start = None;
                    
                    for (i, c) in items_content.chars().enumerate() {
                        match c {
                            '{' => {
                                if depth == 0 {
                                    item_start = Some(i);
                                }
                                depth += 1;
                            }
                            '}' => {
                                depth -= 1;
                                if depth == 0 {
                                    if let Some(start) = item_start {
                                        let item_obj = &items_content[start..=i];
                                        // Parse item_id and quantity
                                        if let (Some(item_id), quantity) = parse_item_reward(item_obj) {
                                            // Add to inventory
                                            let max_stack = get_max_stack_size(&item_id);
                                            let inv = Inventory {
                                                id: 0,
                                                player_id: player_id.to_string(),
                                                item_id: item_id.clone(),
                                                rarity: 0, // Non-fish items have rarity 0
                                                quantity: quantity.min(max_stack),
                                            };
                                            ctx.db.inventory().insert(inv);
                                            log::info!(
                                                "Granted item {} x{} to player {} from quest",
                                                item_id, quantity, player_id
                                            );
                                        }
                                    }
                                    item_start = None;
                                }
                            }
                            _ => {}
                        }
                    }
                }
            }
        }
    }
}

/// Helper: Parse item reward from JSON object
fn parse_item_reward(item_json: &str) -> (Option<String>, u32) {
    let mut item_id = None;
    let mut quantity = 1u32;
    
    // Extract item_id
    if let Some(id_start) = item_json.find("\"item_id\"") {
        let after_key = &item_json[id_start + 9..];
        if let Some(colon_pos) = after_key.find(':') {
            let after_colon = after_key[colon_pos + 1..].trim_start();
            if after_colon.starts_with('"') {
                if let Some(end_quote) = after_colon[1..].find('"') {
                    item_id = Some(after_colon[1..end_quote + 1].to_string());
                }
            }
        }
    }
    
    // Extract quantity
    if let Some(qty) = extract_json_number(item_json, "quantity") {
        quantity = qty;
    }
    
    (item_id, quantity)
}

/// Internal: Update quest progress when a fish is caught
fn update_quest_progress_for_fish(ctx: &ReducerContext, player_id: &str, item_id: &str, rarity: u8) {
    // Find all active quests for this player
    let active_quests: Vec<PlayerQuest> = ctx.db.player_quest().iter()
        .filter(|pq| pq.player_id == player_id && pq.status == "active")
        .collect();
    
    for mut player_quest in active_quests {
        // Update progress JSON
        let mut progress = player_quest.progress.clone();
        
        // Increment the specific fish count
        let fish_count = get_progress_count(&progress, item_id);
        progress = set_progress_count(&progress, item_id, fish_count + 1);
        
        // Increment total count
        let total_count = get_progress_count(&progress, "total");
        progress = set_progress_count(&progress, "total", total_count + 1);
        
        // Update max_rarity if this fish has higher rarity
        let max_rarity = get_progress_count(&progress, "max_rarity");
        if rarity as u32 > max_rarity {
            progress = set_progress_count(&progress, "max_rarity", rarity as u32);
        }
        
        player_quest.progress = progress;
        ctx.db.player_quest().id().update(player_quest.clone());
        
        log::debug!(
            "Updated quest {} progress for player {}: {}",
            player_quest.quest_id, player_id, player_quest.progress
        );
    }
}

/// Helper: Set a count value in progress JSON
fn set_progress_count(progress_json: &str, key: &str, value: u32) -> String {
    let search_key = format!("\"{}\"", key);
    
    if progress_json.contains(&search_key) {
        // Update existing key
        if let Some(key_pos) = progress_json.find(&search_key) {
            let before = &progress_json[..key_pos];
            let after_key = &progress_json[key_pos + search_key.len()..];
            
            if let Some(colon_pos) = after_key.find(':') {
                let after_colon = &after_key[colon_pos + 1..];
                // Find end of number
                let trimmed = after_colon.trim_start();
                let num_end = trimmed.find(|c: char| !c.is_ascii_digit()).unwrap_or(trimmed.len());
                let whitespace_len = after_colon.len() - trimmed.len();
                
                let rest = &after_colon[whitespace_len + num_end..];
                return format!("{}{}:{}{}", before, search_key, value, rest);
            }
        }
    }
    
    // Add new key
    if progress_json == "{}" {
        format!("{{\"{}\":{}}}", key, value)
    } else if progress_json.ends_with('}') {
        format!("{},\"{}\":{}}}", &progress_json[..progress_json.len()-1], key, value)
    } else {
        progress_json.to_string()
    }
}

/// Get all quests available to a player (for quest board display)
#[spacetimedb::reducer]
pub fn get_available_quests(ctx: &ReducerContext, player_id: String) {
    // This is for logging - clients use subscriptions
    let all_quests: Vec<Quest> = ctx.db.quest().iter().collect();
    let player_quests: Vec<PlayerQuest> = ctx.db.player_quest().iter()
        .filter(|pq| pq.player_id == player_id)
        .collect();
    
    let mut available_count = 0;
    let mut active_count = 0;
    let mut completed_count = 0;
    
    for quest in &all_quests {
        let player_quest = player_quests.iter().find(|pq| pq.quest_id == quest.id);
        
        match player_quest {
            Some(pq) if pq.status == "active" => active_count += 1,
            Some(pq) if pq.status == "completed" => completed_count += 1,
            _ => {
                // Check if prerequisites are met
                let prereq_met = match &quest.prerequisite_quest_id {
                    Some(prereq_id) => player_quests.iter()
                        .any(|pq| pq.quest_id == *prereq_id && pq.status == "completed"),
                    None => true,
                };
                if prereq_met {
                    available_count += 1;
                }
            }
        }
    }
    
    log::info!(
        "Player {} quests: {} available, {} active, {} completed",
        player_id, available_count, active_count, completed_count
    );
}

// =============================================================================
// XP & LEVEL SYSTEM REDUCERS
// =============================================================================

/// Internal helper to add XP and handle level ups
fn add_xp_internal(ctx: &ReducerContext, player_id: &str, xp_amount: u64, source: &str) {
    if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id.to_string()) {
        // Initialize level if it's 0 (for existing players before level system)
        if stats.level == 0 {
            stats.level = 1;
            stats.xp_to_next_level = calculate_xp_for_level(2);
        }

        let old_level = stats.level;
        stats.xp += xp_amount;

        // Check for level ups
        while stats.xp >= stats.xp_to_next_level && stats.xp_to_next_level > 0 {
            stats.xp -= stats.xp_to_next_level;
            stats.level += 1;
            stats.xp_to_next_level = calculate_xp_for_level(stats.level + 1);
            log::info!(
                "Player {} leveled up to level {}!",
                player_id, stats.level
            );
        }

        // Save values for logging before update consumes stats
        let new_level = stats.level;
        let new_xp = stats.xp;
        let xp_to_next = stats.xp_to_next_level;

        ctx.db.player_stats().player_id().update(stats);

        if new_level > old_level {
            log::info!(
                "Player {} gained {} XP from {} and reached level {}",
                player_id, xp_amount, source, new_level
            );
        } else {
            log::debug!(
                "Player {} gained {} XP from {} (total: {}/{})",
                player_id, xp_amount, source, new_xp, xp_to_next
            );
        }
    }
}

/// Add XP to a player (public reducer for external calls)
#[spacetimedb::reducer]
pub fn add_xp(ctx: &ReducerContext, player_id: String, amount: u64, source: String) {
    add_xp_internal(ctx, &player_id, amount, &source);
}

/// Record an NPC interaction for a player
#[spacetimedb::reducer]
pub fn record_npc_interaction(
    ctx: &ReducerContext,
    player_id: String,
    npc_id: String,
    interaction_type: String, // "talked", "traded"
) {
    // Verify the NPC exists
    if ctx.db.npc().id().find(&npc_id).is_none() {
        log::warn!("NPC {} not found for interaction", npc_id);
        return;
    }

    // Find or create interaction record
    let existing = ctx.db.player_npc_interaction().iter().find(|i| {
        i.player_id == player_id && i.npc_id == npc_id
    });

    if let Some(mut interaction) = existing {
        // Update existing record
        match interaction_type.as_str() {
            "talked" => {
                interaction.has_talked = true;
                interaction.talk_count += 1;
            }
            "traded" => interaction.has_traded = true,
            _ => {}
        }
        interaction.last_interaction_at = ctx.timestamp;
        ctx.db.player_npc_interaction().id().update(interaction);
        log::debug!(
            "Updated NPC interaction: player {} {} NPC {}",
            player_id, interaction_type, npc_id
        );
    } else {
        // Create new record
        let mut new_interaction = PlayerNpcInteraction {
            id: 0,
            player_id: player_id.clone(),
            npc_id: npc_id.clone(),
            has_talked: false,
            has_traded: false,
            talk_count: 0,
            reputation: 0,
            first_interaction_at: ctx.timestamp,
            last_interaction_at: ctx.timestamp,
        };

        match interaction_type.as_str() {
            "talked" => {
                new_interaction.has_talked = true;
                new_interaction.talk_count = 1;
            }
            "traded" => new_interaction.has_traded = true,
            _ => {}
        }

        ctx.db.player_npc_interaction().insert(new_interaction);
        log::info!(
            "Created NPC interaction: player {} {} NPC {}",
            player_id, interaction_type, npc_id
        );
    }
}

// =============================================================================
// STORYLINE & NPC ADMIN REDUCERS
// =============================================================================

/// Create a new storyline (admin only)
#[spacetimedb::reducer]
pub fn admin_create_storyline(
    ctx: &ReducerContext,
    id: String,
    name: String,
    description: String,
    icon: Option<String>,
    category: String,
    display_order: u32,
    unlock_conditions: Option<String>,
    is_active: bool,
    total_quests: u32,
) {
    if ctx.db.storyline().id().find(&id).is_some() {
        log::warn!("Storyline {} already exists", id);
        return;
    }

    let storyline = Storyline {
        id: id.clone(),
        name: name.clone(),
        description,
        icon,
        category,
        display_order,
        unlock_conditions,
        is_active,
        total_quests,
    };

    ctx.db.storyline().insert(storyline);
    log::info!("Created storyline: {} - {}", id, name);
}

/// Update an existing storyline (admin only)
#[spacetimedb::reducer]
pub fn admin_update_storyline(
    ctx: &ReducerContext,
    id: String,
    name: String,
    description: String,
    icon: Option<String>,
    category: String,
    display_order: u32,
    unlock_conditions: Option<String>,
    is_active: bool,
    total_quests: u32,
) {
    if let Some(mut storyline) = ctx.db.storyline().id().find(&id) {
        storyline.name = name.clone();
        storyline.description = description;
        storyline.icon = icon;
        storyline.category = category;
        storyline.display_order = display_order;
        storyline.unlock_conditions = unlock_conditions;
        storyline.is_active = is_active;
        storyline.total_quests = total_quests;

        ctx.db.storyline().id().update(storyline);
        log::info!("Updated storyline: {} - {}", id, name);
    } else {
        log::warn!("Storyline {} not found", id);
    }
}

/// Delete a storyline (admin only)
#[spacetimedb::reducer]
pub fn admin_delete_storyline(ctx: &ReducerContext, id: String) {
    if ctx.db.storyline().id().find(&id).is_some() {
        ctx.db.storyline().id().delete(&id);
        log::info!("Deleted storyline: {}", id);
    } else {
        log::warn!("Storyline {} not found", id);
    }
}

/// Create a new NPC (admin only)
#[spacetimedb::reducer]
pub fn admin_create_npc(
    ctx: &ReducerContext,
    id: String,
    name: String,
    title: Option<String>,
    description: Option<String>,
    location_x: Option<f32>,
    location_y: Option<f32>,
    sprite_id: Option<String>,
    can_give_quests: bool,
    can_trade: bool,
    is_active: bool,
) {
    if ctx.db.npc().id().find(&id).is_some() {
        log::warn!("NPC {} already exists", id);
        return;
    }

    let npc = Npc {
        id: id.clone(),
        name: name.clone(),
        title,
        description,
        location_x,
        location_y,
        sprite_id,
        can_give_quests,
        can_trade,
        is_active,
    };

    ctx.db.npc().insert(npc);
    log::info!("Created NPC: {} - {}", id, name);
}

/// Update an existing NPC (admin only)
#[spacetimedb::reducer]
pub fn admin_update_npc(
    ctx: &ReducerContext,
    id: String,
    name: String,
    title: Option<String>,
    description: Option<String>,
    location_x: Option<f32>,
    location_y: Option<f32>,
    sprite_id: Option<String>,
    can_give_quests: bool,
    can_trade: bool,
    is_active: bool,
) {
    if let Some(mut npc) = ctx.db.npc().id().find(&id) {
        npc.name = name.clone();
        npc.title = title;
        npc.description = description;
        npc.location_x = location_x;
        npc.location_y = location_y;
        npc.sprite_id = sprite_id;
        npc.can_give_quests = can_give_quests;
        npc.can_trade = can_trade;
        npc.is_active = is_active;

        ctx.db.npc().id().update(npc);
        log::info!("Updated NPC: {} - {}", id, name);
    } else {
        log::warn!("NPC {} not found", id);
    }
}

/// Delete an NPC (admin only)
#[spacetimedb::reducer]
pub fn admin_delete_npc(ctx: &ReducerContext, id: String) {
    if ctx.db.npc().id().find(&id).is_some() {
        ctx.db.npc().id().delete(&id);
        log::info!("Deleted NPC: {}", id);

        // Also delete all player NPC interactions for this NPC
        let interactions_to_delete: Vec<_> = ctx.db.player_npc_interaction()
            .iter()
            .filter(|i| i.npc_id == id)
            .map(|i| i.id)
            .collect();

        for interaction_id in interactions_to_delete {
            ctx.db.player_npc_interaction().id().delete(&interaction_id);
        }
    } else {
        log::warn!("NPC {} not found", id);
    }
}

// =============================================================================
// ITEM DEFINITION ADMIN REDUCERS
// =============================================================================

/// Create a new item definition (admin only)
#[spacetimedb::reducer]
pub fn admin_create_item(
    ctx: &ReducerContext,
    id: String,
    name: String,
    category: String,
    water_type: Option<String>,
    tier: u8,
    buy_price: u32,
    sell_price: u32,
    stack_size: u32,
    sprite_id: String,
    description: Option<String>,
    is_active: bool,
    rarity_multipliers: Option<String>,
    metadata: Option<String>,
) {
    if ctx.db.item_definition().id().find(&id).is_some() {
        log::warn!("Item {} already exists", id);
        return;
    }

    let item = ItemDefinition {
        id: id.clone(),
        name: name.clone(),
        category,
        water_type,
        tier,
        buy_price,
        sell_price,
        stack_size,
        sprite_id,
        description,
        is_active,
        rarity_multipliers,
        metadata,
    };

    ctx.db.item_definition().insert(item);
    log::info!("Created item definition: {} - {}", id, name);
}

/// Update an existing item definition (admin only)
#[spacetimedb::reducer]
pub fn admin_update_item(
    ctx: &ReducerContext,
    id: String,
    name: String,
    category: String,
    water_type: Option<String>,
    tier: u8,
    buy_price: u32,
    sell_price: u32,
    stack_size: u32,
    sprite_id: String,
    description: Option<String>,
    is_active: bool,
    rarity_multipliers: Option<String>,
    metadata: Option<String>,
) {
    if let Some(mut item) = ctx.db.item_definition().id().find(&id) {
        item.name = name.clone();
        item.category = category;
        item.water_type = water_type;
        item.tier = tier;
        item.buy_price = buy_price;
        item.sell_price = sell_price;
        item.stack_size = stack_size;
        item.sprite_id = sprite_id;
        item.description = description;
        item.is_active = is_active;
        item.rarity_multipliers = rarity_multipliers;
        item.metadata = metadata;

        ctx.db.item_definition().id().update(item);
        log::info!("Updated item definition: {} - {}", id, name);
    } else {
        log::warn!("Item {} not found", id);
    }
}

/// Delete an item definition (admin only)
#[spacetimedb::reducer]
pub fn admin_delete_item(ctx: &ReducerContext, id: String) {
    if ctx.db.item_definition().id().find(&id).is_some() {
        ctx.db.item_definition().id().delete(&id);
        log::info!("Deleted item definition: {}", id);
    } else {
        log::warn!("Item {} not found", id);
    }
}

/// Seed default items into the database (admin only)
/// This populates all fish, poles, and lures with their default values
#[spacetimedb::reducer]
pub fn admin_seed_items(ctx: &ReducerContext) {
    let default_rarity_multipliers = Some(r#"{"2": 2.0, "3": 4.0}"#.to_string());

    // Fish - Pond
    seed_item(ctx, "fish_pond_1", "Pond Sunfish", "fish", Some("pond"), 1, 0, 10, 5, "A common sunfish found in peaceful ponds.", &default_rarity_multipliers);
    seed_item(ctx, "fish_pond_2", "Pond Bass", "fish", Some("pond"), 2, 0, 25, 5, "A medium-sized bass dwelling in calm waters.", &default_rarity_multipliers);
    seed_item(ctx, "fish_pond_3", "Pond Pike", "fish", Some("pond"), 3, 0, 50, 5, "A rare pike that lurks in pond depths.", &default_rarity_multipliers);
    seed_item(ctx, "fish_pond_4", "Pond Legend", "fish", Some("pond"), 4, 0, 150, 5, "A legendary fish of pond lore.", &default_rarity_multipliers);

    // Fish - River
    seed_item(ctx, "fish_river_1", "River Trout", "fish", Some("river"), 1, 0, 12, 5, "A common trout swimming in rivers.", &default_rarity_multipliers);
    seed_item(ctx, "fish_river_2", "River Salmon", "fish", Some("river"), 2, 0, 30, 5, "A strong salmon fighting the current.", &default_rarity_multipliers);
    seed_item(ctx, "fish_river_3", "River Catfish", "fish", Some("river"), 3, 0, 60, 5, "A rare catfish hiding among river rocks.", &default_rarity_multipliers);
    seed_item(ctx, "fish_river_4", "River Monster", "fish", Some("river"), 4, 0, 180, 5, "A legendary river monster of ancient tales.", &default_rarity_multipliers);

    // Fish - Ocean
    seed_item(ctx, "fish_ocean_1", "Ocean Mackerel", "fish", Some("ocean"), 1, 0, 15, 5, "A common mackerel from the open sea.", &default_rarity_multipliers);
    seed_item(ctx, "fish_ocean_2", "Ocean Tuna", "fish", Some("ocean"), 2, 0, 40, 5, "A powerful tuna from deep waters.", &default_rarity_multipliers);
    seed_item(ctx, "fish_ocean_3", "Ocean Marlin", "fish", Some("ocean"), 3, 0, 80, 5, "A rare marlin with a magnificent bill.", &default_rarity_multipliers);
    seed_item(ctx, "fish_ocean_4", "Ocean Leviathan", "fish", Some("ocean"), 4, 0, 250, 5, "A legendary sea creature from the abyss.", &default_rarity_multipliers);

    // Fish - Night
    seed_item(ctx, "fish_night_1", "Night Eel", "fish", Some("night"), 1, 0, 20, 5, "A slippery eel that emerges at night.", &default_rarity_multipliers);
    seed_item(ctx, "fish_night_2", "Night Lanternfish", "fish", Some("night"), 2, 0, 45, 5, "A glowing fish that lights the dark waters.", &default_rarity_multipliers);
    seed_item(ctx, "fish_night_3", "Night Anglerfish", "fish", Some("night"), 3, 0, 90, 5, "A rare anglerfish with a luminous lure.", &default_rarity_multipliers);
    seed_item(ctx, "fish_night_4", "Night Phantom", "fish", Some("night"), 4, 0, 300, 5, "A legendary phantom fish seen only under moonlight.", &default_rarity_multipliers);

    // Poles
    seed_item(ctx, "pole_1", "Starter Rod", "pole", None, 1, 0, 0, 1, "A basic fishing rod for beginners.", &None);
    seed_item(ctx, "pole_2", "Steel Rod", "pole", None, 2, 200, 200, 1, "An improved rod with better durability.", &None);
    seed_item(ctx, "pole_3", "Carbon Rod", "pole", None, 3, 500, 500, 1, "An advanced carbon fiber fishing rod.", &None);
    seed_item(ctx, "pole_4", "Legendary Rod", "pole", None, 4, 1500, 1500, 1, "A masterwork rod crafted by experts.", &None);

    // Lures
    seed_item(ctx, "lure_1", "Basic Lure", "lure", None, 1, 20, 10, 99, "A simple lure for basic fishing.", &None);
    seed_item(ctx, "lure_2", "Spinner Lure", "lure", None, 2, 60, 30, 99, "A spinning lure that attracts fish.", &None);
    seed_item(ctx, "lure_3", "Premium Lure", "lure", None, 3, 160, 80, 99, "A high-quality lure for serious anglers.", &None);
    seed_item(ctx, "lure_4", "Master Lure", "lure", None, 4, 500, 250, 99, "A legendary lure that fish cannot resist.", &None);

    log::info!("Seeded default item definitions");
}

/// Helper function to seed a single item (only if it doesn't exist)
fn seed_item(
    ctx: &ReducerContext,
    id: &str,
    name: &str,
    category: &str,
    water_type: Option<&str>,
    tier: u8,
    buy_price: u32,
    sell_price: u32,
    stack_size: u32,
    description: &str,
    rarity_multipliers: &Option<String>,
) {
    if ctx.db.item_definition().id().find(&id.to_string()).is_some() {
        return; // Already exists, skip
    }

    ctx.db.item_definition().insert(ItemDefinition {
        id: id.to_string(),
        name: name.to_string(),
        category: category.to_string(),
        water_type: water_type.map(|s| s.to_string()),
        tier,
        buy_price,
        sell_price,
        stack_size,
        sprite_id: id.to_string(), // Default sprite_id matches item id
        description: Some(description.to_string()),
        is_active: true,
        rarity_multipliers: rarity_multipliers.clone(),
        metadata: None,
    });
}

// =============================================================================
// SESSION & EVENT TRACKING REDUCERS
// =============================================================================

/// Internal helper to get the current active session ID for a player
fn get_active_session_id(ctx: &ReducerContext, player_id: &str) -> Option<u64> {
    ctx.db.player_session().iter()
        .find(|s| s.player_id == player_id && s.is_active)
        .map(|s| s.id)
}

/// Internal helper to log an event
fn log_event_internal(
    ctx: &ReducerContext,
    player_id: String,
    event_type: String,
    item_id: Option<String>,
    quantity: Option<u32>,
    gold_amount: Option<u32>,
    rarity: Option<u8>,
    water_body_id: Option<String>,
    metadata: Option<String>,
) {
    let session_id = get_active_session_id(ctx, &player_id);
    
    let event = GameEvent {
        id: 0, // auto-incremented
        player_id: player_id.clone(),
        session_id,
        event_type: event_type.clone(),
        item_id,
        quantity,
        gold_amount,
        rarity,
        water_body_id,
        metadata,
        created_at: ctx.timestamp,
    };
    
    ctx.db.game_event().insert(event);
    log::debug!("Event logged: {} for player {}", event_type, player_id);
}

/// Start a new session for a player
/// Called when a player joins the world
#[spacetimedb::reducer]
pub fn start_session(ctx: &ReducerContext, player_id: String) {
    // End any existing active sessions for this player (shouldn't happen normally)
    let active_sessions: Vec<PlayerSession> = ctx.db.player_session().iter()
        .filter(|s| s.player_id == player_id && s.is_active)
        .collect();
    
    for mut session in active_sessions {
        // Calculate duration
        let duration = (ctx.timestamp.to_micros_since_unix_epoch() - session.started_at.to_micros_since_unix_epoch()) / 1_000_000;
        session.ended_at = Some(ctx.timestamp);
        session.duration_seconds = duration as u64;
        session.is_active = false;
        ctx.db.player_session().id().update(session);
        log::warn!("Closed orphaned session for player {}", player_id);
    }
    
    // Create new session
    let session = PlayerSession {
        id: 0, // auto-incremented
        player_id: player_id.clone(),
        started_at: ctx.timestamp,
        ended_at: None,
        duration_seconds: 0,
        is_active: true,
    };
    
    ctx.db.player_session().insert(session);
    
    // Update or create player stats
    if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
        stats.total_sessions += 1;
        stats.last_seen_at = ctx.timestamp;
        ctx.db.player_stats().player_id().update(stats);
    } else {
        let stats = PlayerStats {
            player_id: player_id.clone(),
            total_playtime_seconds: 0,
            total_sessions: 1,
            total_fish_caught: 0,
            total_gold_earned: 0,
            total_gold_spent: 0,
            first_seen_at: ctx.timestamp,
            last_seen_at: ctx.timestamp,
            // Level system - start at level 1
            level: 1,
            xp: 0,
            xp_to_next_level: calculate_xp_for_level(2), // XP needed to reach level 2
        };
        ctx.db.player_stats().insert(stats);
    }
    
    // Log session started event
    log_event_internal(
        ctx,
        player_id.clone(),
        "session_started".to_string(),
        None, None, None, None, None, None,
    );
    
    log::info!("Session started for player {}", player_id);
}

/// End the current session for a player
/// Called when a player leaves the world or disconnects
#[spacetimedb::reducer]
pub fn end_session(ctx: &ReducerContext, player_id: String) {
    // Find active session
    let active_session = ctx.db.player_session().iter()
        .find(|s| s.player_id == player_id && s.is_active);
    
    if let Some(mut session) = active_session {
        // Calculate duration in seconds
        let duration = (ctx.timestamp.to_micros_since_unix_epoch() - session.started_at.to_micros_since_unix_epoch()) / 1_000_000;
        session.ended_at = Some(ctx.timestamp);
        session.duration_seconds = duration as u64;
        session.is_active = false;
        
        let session_duration = session.duration_seconds;
        ctx.db.player_session().id().update(session);
        
        // Update player stats with playtime
        if let Some(mut stats) = ctx.db.player_stats().player_id().find(&player_id) {
            stats.total_playtime_seconds += session_duration;
            stats.last_seen_at = ctx.timestamp;
            ctx.db.player_stats().player_id().update(stats);
        }
        
        // Log session ended event with duration metadata
        log_event_internal(
            ctx,
            player_id.clone(),
            "session_ended".to_string(),
            None, None, None, None, None,
            Some(format!("{{\"duration_seconds\":{}}}", session_duration)),
        );
        
        log::info!("Session ended for player {} (duration: {}s)", player_id, session_duration);
    }
}

/// Log a generic game event (public reducer for external calls)
#[spacetimedb::reducer]
pub fn log_game_event(
    ctx: &ReducerContext,
    player_id: String,
    event_type: String,
    item_id: Option<String>,
    quantity: Option<u32>,
    gold_amount: Option<u32>,
    rarity: Option<u8>,
    water_body_id: Option<String>,
    metadata: Option<String>,
) {
    log_event_internal(
        ctx,
        player_id,
        event_type,
        item_id,
        quantity,
        gold_amount,
        rarity,
        water_body_id,
        metadata,
    );
}

/// Get player stats (for querying)
#[spacetimedb::reducer]
pub fn get_player_stats(ctx: &ReducerContext, player_id: String) {
    // This is just for logging/debugging - clients use subscriptions
    if let Some(stats) = ctx.db.player_stats().player_id().find(&player_id) {
        log::info!(
            "Player {} stats: sessions={}, playtime={}s, fish={}, gold_earned={}, gold_spent={}",
            player_id,
            stats.total_sessions,
            stats.total_playtime_seconds,
            stats.total_fish_caught,
            stats.total_gold_earned,
            stats.total_gold_spent
        );
    } else {
        log::info!("No stats found for player {}", player_id);
    }
}

/// Log item sold event (called from bridge when selling items)
#[spacetimedb::reducer]
pub fn log_item_sold(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    rarity: u8,
    quantity: u32,
    gold_amount: u32,
) {
    log_event_internal(
        ctx,
        player_id.clone(),
        "item_sold".to_string(),
        Some(item_id.clone()),
        Some(quantity),
        Some(gold_amount),
        Some(rarity),
        None,
        None,
    );
    log::info!(
        "Player {} sold {}x {} (rarity {}) for {}g",
        player_id, quantity, item_id, rarity, gold_amount
    );
}

/// Log item bought event (called from bridge when buying items)
#[spacetimedb::reducer]
pub fn log_item_bought(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    quantity: u32,
    gold_amount: u32,
) {
    log_event_internal(
        ctx,
        player_id.clone(),
        "item_bought".to_string(),
        Some(item_id.clone()),
        Some(quantity),
        Some(gold_amount),
        Some(0), // Non-fish items have rarity 0
        None,
        None,
    );
    log::info!(
        "Player {} bought {}x {} for {}g",
        player_id, quantity, item_id, gold_amount
    );
}

// =============================================================================
// ADMIN: QUEST MANAGEMENT
// =============================================================================

/// Create a new quest (admin only)
#[spacetimedb::reducer]
pub fn admin_create_quest(
    ctx: &ReducerContext,
    id: String,
    title: String,
    description: String,
    quest_type: String,
    storyline: Option<String>,
    story_order: Option<u32>,
    prerequisite_quest_id: Option<String>,
    requirements: String,
    rewards: String,
    quest_giver_type: Option<String>,
    quest_giver_id: Option<String>,
) {
    // Check if quest already exists
    if ctx.db.quest().id().find(&id).is_some() {
        log::warn!("Quest {} already exists", id);
        return;
    }

    let quest = Quest {
        id: id.clone(),
        title: title.clone(),
        description,
        quest_type,
        storyline,
        story_order,
        prerequisite_quest_id,
        requirements,
        rewards,
        quest_giver_type,
        quest_giver_id,
    };

    ctx.db.quest().insert(quest);
    log::info!("Created quest: {} - {}", id, title);
}

/// Update an existing quest (admin only)
#[spacetimedb::reducer]
pub fn admin_update_quest(
    ctx: &ReducerContext,
    id: String,
    title: String,
    description: String,
    quest_type: String,
    storyline: Option<String>,
    story_order: Option<u32>,
    prerequisite_quest_id: Option<String>,
    requirements: String,
    rewards: String,
    quest_giver_type: Option<String>,
    quest_giver_id: Option<String>,
) {
    // Find existing quest
    if let Some(mut quest) = ctx.db.quest().id().find(&id) {
        quest.title = title.clone();
        quest.description = description;
        quest.quest_type = quest_type;
        quest.storyline = storyline;
        quest.story_order = story_order;
        quest.prerequisite_quest_id = prerequisite_quest_id;
        quest.requirements = requirements;
        quest.rewards = rewards;
        quest.quest_giver_type = quest_giver_type;
        quest.quest_giver_id = quest_giver_id;

        ctx.db.quest().id().update(quest);
        log::info!("Updated quest: {} - {}", id, title);
    } else {
        log::warn!("Quest {} not found", id);
    }
}

/// Delete a quest (admin only) - also removes all player progress for this quest
#[spacetimedb::reducer]
pub fn admin_delete_quest(ctx: &ReducerContext, id: String) {
    // Delete the quest
    if let Some(quest) = ctx.db.quest().id().find(&id) {
        ctx.db.quest().id().delete(&id);
        log::info!("Deleted quest: {} - {}", id, quest.title);
        
        // Also delete all player quest progress for this quest
        let player_quests_to_delete: Vec<_> = ctx.db.player_quest()
            .iter()
            .filter(|pq| pq.quest_id == id)
            .map(|pq| pq.id)
            .collect();
        
        for pq_id in player_quests_to_delete {
            ctx.db.player_quest().id().delete(&pq_id);
        }
    } else {
        log::warn!("Quest {} not found", id);
    }
}

/// Reset all player progress for a specific quest (admin only)
#[spacetimedb::reducer]
pub fn admin_reset_quest_progress(ctx: &ReducerContext, quest_id: String) {
    let player_quests_to_delete: Vec<_> = ctx.db.player_quest()
        .iter()
        .filter(|pq| pq.quest_id == quest_id)
        .map(|pq| pq.id)
        .collect();
    
    let count = player_quests_to_delete.len();
    for pq_id in player_quests_to_delete {
        ctx.db.player_quest().id().delete(&pq_id);
    }
    
    log::info!("Reset progress for quest {} ({} player entries deleted)", quest_id, count);
}

// =============================================================================
// INITIALIZATION
// =============================================================================

/// Initialize the database with world data
#[spacetimedb::reducer(init)]
pub fn init(ctx: &ReducerContext) {
    // Add spawn points spread across the playable area (avoiding ocean on left)
    let spawn_points = vec![
        SpawnPoint { id: "spawn_1".to_string(), x: 400.0, y: 300.0, name: "Top Left".to_string() },
        SpawnPoint { id: "spawn_2".to_string(), x: 1700.0, y: 300.0, name: "Top Right".to_string() },
        SpawnPoint { id: "spawn_3".to_string(), x: 1000.0, y: 1000.0, name: "Center".to_string() },
        SpawnPoint { id: "spawn_4".to_string(), x: 400.0, y: 1700.0, name: "Bottom Left".to_string() },
        SpawnPoint { id: "spawn_5".to_string(), x: 1700.0, y: 1700.0, name: "Bottom Right".to_string() },
    ];
    
    for spawn in &spawn_points {
        ctx.db.spawn_point().insert(spawn.clone());
    }
    log::info!("Initialized {} spawn points", spawn_points.len());
    
    // Add ponds (matching frontend lurelands_game.dart)
    let ponds = vec![
        Pond { id: "pond_1".to_string(), x: 600.0, y: 600.0, radius: 100.0 },
        Pond { id: "pond_2".to_string(), x: 1400.0, y: 1200.0, radius: 80.0 },
    ];
    
    for pond in &ponds {
        ctx.db.pond().insert(pond.clone());
    }
    log::info!("Initialized {} ponds", ponds.len());
    
    // Add rivers (matching frontend lurelands_game.dart)
    let rivers = vec![
        River {
            id: "river_1".to_string(),
            x: 1000.0,
            y: 400.0,
            width: 80.0,
            length: 600.0,
            rotation: 0.3, // Slight diagonal
        },
    ];
    
    for river in &rivers {
        ctx.db.river().insert(river.clone());
    }
    log::info!("Initialized {} rivers", rivers.len());
    
    // Add ocean (on the left side of the map)
    let ocean = Ocean {
        id: "ocean_1".to_string(),
        x: 0.0,
        y: 0.0,
        width: 250.0,
        height: 2000.0,
    };
    ctx.db.ocean().insert(ocean);
    log::info!("Initialized ocean");
    
    // ==========================================================================
    // QUEST INITIALIZATION
    // ==========================================================================
    
    // Fisherman's Guild Storyline
    let guild_quests = vec![
        Quest {
            id: "guild_1".to_string(),
            title: "Guild Initiation".to_string(),
            description: "Prove your worth to the Fisherman's Guild by catching any 2 fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(1),
            prerequisite_quest_id: None,
            requirements: r#"{"total_fish": 2}"#.to_string(),
            rewards: r#"{"gold": 50}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "guild_2".to_string(),
            title: "Freshwater Mastery".to_string(),
            description: "Master the art of freshwater fishing. Catch 3 pond fish and 2 river fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(2),
            prerequisite_quest_id: Some("guild_1".to_string()),
            requirements: r#"{"fish": {"fish_pond_1": 1, "fish_pond_2": 1, "fish_pond_3": 1, "fish_river_1": 1, "fish_river_2": 1}}"#.to_string(),
            rewards: r#"{"gold": 100, "items": [{"item_id": "pole_2", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "guild_3".to_string(),
            title: "Guild Champion".to_string(),
            description: "Become a true champion! Catch a rare 3-star fish of any type.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(3),
            prerequisite_quest_id: Some("guild_2".to_string()),
            requirements: r#"{"min_rarity": 3}"#.to_string(),
            rewards: r#"{"gold": 300, "items": [{"item_id": "pole_3", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in &guild_quests {
        ctx.db.quest().insert(quest.clone());
    }
    log::info!("Initialized {} Fisherman's Guild quests", guild_quests.len());
    
    // Ocean Mysteries Storyline
    let ocean_quests = vec![
        Quest {
            id: "ocean_1".to_string(),
            title: "Coastal Curiosity".to_string(),
            description: "The ocean holds many secrets. Start by catching 3 ocean fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("ocean_mysteries".to_string()),
            story_order: Some(1),
            prerequisite_quest_id: None,
            requirements: r#"{"fish": {"fish_ocean_1": 1, "fish_ocean_2": 1, "fish_ocean_3": 1}}"#.to_string(),
            rewards: r#"{"gold": 75}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "ocean_2".to_string(),
            title: "Deep Waters".to_string(),
            description: "Venture deeper into the ocean's mysteries. Catch 5 ocean fish including at least one 2-star.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("ocean_mysteries".to_string()),
            story_order: Some(2),
            prerequisite_quest_id: Some("ocean_1".to_string()),
            requirements: r#"{"total_fish": 5, "min_rarity": 2}"#.to_string(),
            rewards: r#"{"gold": 200, "items": [{"item_id": "lure_2", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in &ocean_quests {
        ctx.db.quest().insert(quest.clone());
    }
    log::info!("Initialized {} Ocean Mysteries quests", ocean_quests.len());
    
    // Daily Quests
    let daily_quests = vec![
        Quest {
            id: "daily_haul".to_string(),
            title: "Daily Haul".to_string(),
            description: "A simple task for any fisher. Catch 5 fish of any type today.".to_string(),
            quest_type: "daily".to_string(),
            storyline: None,
            story_order: None,
            prerequisite_quest_id: None,
            requirements: r#"{"total_fish": 5}"#.to_string(),
            rewards: r#"{"gold": 25}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in &daily_quests {
        ctx.db.quest().insert(quest.clone());
    }
    log::info!("Initialized {} daily quests", daily_quests.len());
    
    log::info!("Lurelands server initialization complete");
}

/// Admin reducer to seed default quests (can be called anytime to add missing quests)
#[spacetimedb::reducer]
pub fn admin_seed_quests(ctx: &ReducerContext) {
    let mut added = 0;
    let mut skipped = 0;
    
    // Fisherman's Guild Storyline
    let guild_quests = vec![
        Quest {
            id: "guild_1".to_string(),
            title: "Guild Initiation".to_string(),
            description: "Prove your worth to the Fisherman's Guild by catching any 2 fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(1),
            prerequisite_quest_id: None,
            requirements: r#"{"total_fish": 2}"#.to_string(),
            rewards: r#"{"gold": 50}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "guild_2".to_string(),
            title: "Freshwater Mastery".to_string(),
            description: "Master the art of freshwater fishing. Catch 3 pond fish and 2 river fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(2),
            prerequisite_quest_id: Some("guild_1".to_string()),
            requirements: r#"{"fish": {"fish_pond_1": 1, "fish_pond_2": 1, "fish_pond_3": 1, "fish_river_1": 1, "fish_river_2": 1}}"#.to_string(),
            rewards: r#"{"gold": 100, "items": [{"item_id": "pole_2", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "guild_3".to_string(),
            title: "Guild Champion".to_string(),
            description: "Become a true champion! Catch a rare 3-star fish of any type.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("fishermans_guild".to_string()),
            story_order: Some(3),
            prerequisite_quest_id: Some("guild_2".to_string()),
            requirements: r#"{"min_rarity": 3}"#.to_string(),
            rewards: r#"{"gold": 300, "items": [{"item_id": "pole_3", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in guild_quests {
        if ctx.db.quest().id().find(&quest.id).is_none() {
            ctx.db.quest().insert(quest);
            added += 1;
        } else {
            skipped += 1;
        }
    }
    
    // Ocean Mysteries Storyline
    let ocean_quests = vec![
        Quest {
            id: "ocean_1".to_string(),
            title: "Coastal Curiosity".to_string(),
            description: "The ocean holds many secrets. Start by catching 3 ocean fish.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("ocean_mysteries".to_string()),
            story_order: Some(1),
            prerequisite_quest_id: None,
            requirements: r#"{"fish": {"fish_ocean_1": 1, "fish_ocean_2": 1, "fish_ocean_3": 1}}"#.to_string(),
            rewards: r#"{"gold": 75}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
        Quest {
            id: "ocean_2".to_string(),
            title: "Deep Waters".to_string(),
            description: "Venture deeper into the ocean's mysteries. Catch 5 ocean fish including at least one 2-star.".to_string(),
            quest_type: "story".to_string(),
            storyline: Some("ocean_mysteries".to_string()),
            story_order: Some(2),
            prerequisite_quest_id: Some("ocean_1".to_string()),
            requirements: r#"{"total_fish": 5, "min_rarity": 2}"#.to_string(),
            rewards: r#"{"gold": 200, "items": [{"item_id": "lure_2", "quantity": 1}]}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in ocean_quests {
        if ctx.db.quest().id().find(&quest.id).is_none() {
            ctx.db.quest().insert(quest);
            added += 1;
        } else {
            skipped += 1;
        }
    }
    
    // Daily Quests
    let daily_quests = vec![
        Quest {
            id: "daily_haul".to_string(),
            title: "Daily Haul".to_string(),
            description: "A simple task for any fisher. Catch 5 fish of any type today.".to_string(),
            quest_type: "daily".to_string(),
            storyline: None,
            story_order: None,
            prerequisite_quest_id: None,
            requirements: r#"{"total_fish": 5}"#.to_string(),
            rewards: r#"{"gold": 25}"#.to_string(),
            quest_giver_type: None,
            quest_giver_id: None,
        },
    ];
    
    for quest in daily_quests {
        if ctx.db.quest().id().find(&quest.id).is_none() {
            ctx.db.quest().insert(quest);
            added += 1;
        } else {
            skipped += 1;
        }
    }
    
    log::info!("Admin seeded quests: {} added, {} already existed", added, skipped);
}
