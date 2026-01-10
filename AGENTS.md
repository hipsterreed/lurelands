# Lurelands - Agent Instructions

This is a multiplayer fishing game built with Flutter, SpacetimeDB, and a TypeScript bridge service.

## Project Structure

```
lurelands/
├── apps/
│   └── lurelands/              # Flutter client app (main game)
├── services/
│   ├── spacetime-server/       # SpacetimeDB Rust module (schema + game logic)
│   └── bridge/                 # TypeScript WebSocket bridge (Bun + Elysia)
└── cli/                        # Go CLI for development commands
```

### Apps

The `apps/` folder contains our client applications:

- **lurelands** (Flutter) - This is our main app, the Lurelands fishing game. Built with Flutter and the Flame game engine, it's a multiplayer fishing RPG where players can fish, collect items, and explore the world.

- **admin** (NextJS) - *Coming soon* - An admin dashboard for managing the game from an administrative standpoint. This will be used for game management, analytics, and content management.

### Services

The `services/` folder contains our backend infrastructure:

- **spacetime-server** - Contains our SpacetimeDB schema and game logic written in Rust. This defines all our database tables, reducers, and server-side game logic. We always connect to the hosted SpacetimeDB instance (maincloud) both locally during development and in production - we don't run SpacetimeDB locally.

- **bridge** - A TypeScript WebSocket service that acts as the communication layer between our apps and the SpacetimeDB database. The bridge handles all real-time data synchronization, translating between the Flutter client and SpacetimeDB.

### CLI

The `cli/` folder contains a Go-based command-line tool used locally for development tasks:

- Push schema changes to SpacetimeDB
- Run builds and deployments
- Generate TypeScript types from the Rust schema
- Run the Flutter app on various devices

## CLI Usage

The `lurelands` CLI provides all common development commands. Run without arguments for interactive TUI mode.

### Full Deployment (Recommended)

After making changes to the SpacetimeDB module (`services/spacetime-server/src/lib.rs`):

```bash
# Deploy to maincloud (production)
lurelands deploy:full

# Deploy locally (development)
lurelands deploy:full:local
```

These commands automatically:
1. Publish the Rust module to SpacetimeDB
2. Generate TypeScript types for the bridge
3. Build the bridge service

### Individual Commands

```bash
# Flutter
lurelands run              # Run on default device
lurelands run:ios          # Run on iOS
lurelands run:android      # Run on Android
lurelands run:web          # Run on Chrome

# Database
lurelands deploy           # Publish to maincloud
lurelands deploy:local     # Publish locally

# Bridge
lurelands bridge:build     # Build the bridge service
lurelands bridge:dev       # Run bridge in dev mode (hot reload)
lurelands bridge:start     # Run bridge in production mode
lurelands bridge:generate  # Regenerate TypeScript types from SpacetimeDB
```

## Architecture

### SpacetimeDB Module (Rust)

Located at `services/spacetime-server/src/lib.rs`. Contains:

**Core Tables:**
- `Player` - Player state, position, gold, equipped items
- `Inventory` - Player item stacks (fish, poles, lures)
- `FishCatch` - Historical log of caught fish
- `SpawnPoint`, `Pond`, `River`, `Ocean` - World data

**Session & Analytics Tables:**
- `PlayerSession` - Individual play sessions with timestamps and duration
- `PlayerStats` - Aggregated lifetime statistics per player
- `GameEvent` - Detailed event log for all player actions

**Event Types Tracked:**
| Event | Properties |
|-------|------------|
| `fish_caught` | player, session, item_id, quantity, rarity, water_body, fish_type, size |
| `item_sold` | player, session, item_id, quantity, gold_amount, rarity |
| `item_bought` | player, session, item_id, quantity, gold_amount |
| `session_started` | player, timestamp |
| `session_ended` | player, duration_seconds |
| `pole_equipped` | player, session, item_id |
| `pole_unequipped` | player, session, item_id |

### Bridge Service (TypeScript/Bun)

Located at `services/bridge/`. Acts as WebSocket intermediary between Flutter clients and SpacetimeDB.

- `src/index.ts` - Elysia WebSocket server
- `src/stdb-client.ts` - SpacetimeDB client wrapper
- `src/types.ts` - Shared TypeScript types
- `src/generated/` - Auto-generated SpacetimeDB bindings (via `lurelands bridge:generate`)

### Flutter Client

Located at `apps/lurelands/`. Uses Flame game engine.

Key files:
- `lib/main.dart` - App entry point
- `lib/screens/game_screen.dart` - Main game UI
- `lib/game/lurelands_game.dart` - Flame game logic
- `lib/widgets/` - UI panels (inventory, shop, etc.)

## Development Workflow

1. **Making SpacetimeDB changes:**
   ```bash
   # Edit services/spacetime-server/src/lib.rs
   lurelands deploy:full:local  # Deploys and regenerates types
   ```

2. **Running the full stack locally:**
   ```bash
   # Terminal 1: Start the bridge
   lurelands bridge:dev

   # Terminal 2: Run Flutter app
   lurelands run
   ```

3. **Production deployment:**
   ```bash
   # Step 1: Deploy SpacetimeDB module to maincloud and rebuild bridge
   lurelands deploy:full

   # Step 2: Deploy bridge to Railway
   cd services/bridge
   railway up
   ```

   Or if Railway is connected to Git, just push your changes and Railway will auto-deploy.

## Production Architecture

```
┌─────────────┐     WebSocket     ┌─────────────┐     SpacetimeDB     ┌─────────────────┐
│   Flutter   │ ←───────────────→ │   Bridge    │ ←─────────────────→ │  SpacetimeDB    │
│   Client    │                   │  (Railway)  │                     │   (maincloud)   │
└─────────────┘                   └─────────────┘                     └─────────────────┘
```

- **SpacetimeDB**: Always hosted on SpacetimeDB maincloud (`wss://maincloud.spacetimedb.com`) - both for local development and production
- **Bridge Service**: Hosted on Railway (Dockerfile-based, Bun runtime)
- **Flutter Client**: Connects to Railway bridge which proxies to SpacetimeDB

### Environment Variables (Railway)

The bridge service requires these env vars in Railway:
- `SPACETIMEDB_URI` - SpacetimeDB WebSocket URL (e.g., `wss://maincloud.spacetimedb.com`)
- `SPACETIMEDB_MODULE` - Module name (`lurelands`)
- `PORT` - Defaults to `8080`
- `HOST` - Defaults to `0.0.0.0`

## Querying Analytics Data

The session and event tables can be queried via SpacetimeDB SQL subscriptions or the SpacetimeDB CLI:

```bash
# View player stats
spacetime sql lurelands "SELECT * FROM player_stats"

# View recent sessions
spacetime sql lurelands "SELECT * FROM player_session ORDER BY started_at DESC LIMIT 10"

# View recent events
spacetime sql lurelands "SELECT * FROM game_event ORDER BY created_at DESC LIMIT 50"

# Events for a specific player
spacetime sql lurelands "SELECT * FROM game_event WHERE player_id = 'player123'"

# Fish catch analytics
spacetime sql lurelands "SELECT player_id, COUNT(*) as catches FROM game_event WHERE event_type = 'fish_caught' GROUP BY player_id"
```
