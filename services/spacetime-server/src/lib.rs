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
        last_updated: ctx.timestamp,
    };
    
    ctx.db.player().insert(player);
    log::info!("Player {} joined the world at ({}, {})", player_id, spawn_x, spawn_y);
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
    fish_id: String,
    fish_type: String,
    size: f32,
    rarity: String,
    water_body_id: String,
) {
    let catch = FishCatch {
        id: 0, // auto-incremented
        fish_id: fish_id.clone(),
        player_id: player_id.clone(),
        fish_type,
        size,
        rarity,
        water_body_id,
        released: false,
        caught_at: ctx.timestamp,
    };
    
    ctx.db.fish_catch().insert(catch);
    log::info!("Player {} caught fish {}", player_id, fish_id);
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
            last_updated: ctx.timestamp,
        };
        
        ctx.db.player().insert(player);
        log::info!("Player {} created with name: {} at ({}, {})", player_id, name, spawn_x, spawn_y);
    }
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
