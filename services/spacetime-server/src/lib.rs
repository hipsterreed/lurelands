//! Lurelands SpacetimeDB Server Module
//!
//! This module handles real-time multiplayer synchronization for the Lurelands game.
//! Players connect via WebSocket and their state is synchronized across all clients.

use spacetimedb::{ReducerContext, Table, Timestamp};

/// Player table - tracks all connected players in the game world
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
        Some(item_id),
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
#[spacetimedb::reducer]
pub fn remove_from_inventory(
    ctx: &ReducerContext,
    player_id: String,
    item_id: String,
    rarity: u8,
    quantity: u32,
) {
    // Find the inventory stack
    let existing = ctx.db.inventory().iter().find(|inv| {
        inv.player_id == player_id && inv.item_id == item_id && inv.rarity == rarity
    });
    
    if let Some(mut inv) = existing {
        if inv.quantity <= quantity {
            // Remove the entire stack
            ctx.db.inventory().id().delete(&inv.id);
            log::info!(
                "Removed entire stack from inventory for player {}: {} (rarity {})",
                player_id, item_id, rarity
            );
        } else {
            // Reduce the quantity
            inv.quantity -= quantity;
            let new_quantity = inv.quantity;
            ctx.db.inventory().id().update(inv);
            log::info!(
                "Removed {} from inventory for player {}: {} x{} (rarity {})",
                quantity, player_id, item_id, new_quantity, rarity
            );
        }
    } else {
        log::warn!(
            "No inventory stack found for player {} item {} (rarity {})",
            player_id, item_id, rarity
        );
    }
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
    
    log::info!("Lurelands server initialization complete");
}
