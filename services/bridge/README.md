# Lurelands Bridge Service

WebSocket bridge between Flutter clients and SpacetimeDB.

## Overview

This service acts as a protocol bridge:
- **Flutter clients** connect via WebSocket using JSON messages
- **SpacetimeDB** is connected via the official TypeScript SDK (BSATN protocol)

## Quick Start

### Prerequisites
- [Bun](https://bun.sh) runtime
- SpacetimeDB running locally (`spacetime start`)
- Lurelands module published (`spacetime publish lurelands`)

### Development

```bash
# Install dependencies
bun install

# Run in development mode (with hot reload)
bun run dev

# Run in production mode
bun run start
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Server port |
| `HOST` | `0.0.0.0` | Server host |
| `SPACETIMEDB_URI` | `ws://localhost:3000` | SpacetimeDB server URI |
| `SPACETIMEDB_MODULE` | `lurelands` | SpacetimeDB module name |

### Production (SpacetimeDB Cloud)

```bash
SPACETIMEDB_URI=wss://mainnet.spacetimedb.com bun run start
```

## API

### HTTP Endpoints

- `GET /` - Service status
- `GET /health` - Health check

### WebSocket Endpoint

Connect to `ws://localhost:8080/ws`

#### Client → Server Messages

```json
{ "type": "join", "playerId": "xxx", "name": "Player", "color": 16711680 }
{ "type": "move", "x": 500, "y": 300, "angle": 1.57 }
{ "type": "cast", "targetX": 600, "targetY": 400 }
{ "type": "reel" }
{ "type": "leave" }
```

#### Server → Client Messages

```json
{ "type": "connected", "playerId": "xxx" }
{ "type": "world_state", "data": { "ponds": [...], "rivers": [...], ... } }
{ "type": "spawn", "x": 400, "y": 300 }
{ "type": "players", "players": [...] }
{ "type": "player_joined", "player": {...} }
{ "type": "player_left", "playerId": "xxx" }
{ "type": "player_updated", "player": {...} }
{ "type": "fish_caught", "catch": {...} }
{ "type": "error", "message": "..." }
```

## Deployment

### Railway

1. Create new project on Railway
2. Connect your GitHub repository
3. Set environment variables:
   - `SPACETIMEDB_URI=wss://mainnet.spacetimedb.com`
   - `SPACETIMEDB_MODULE=lurelands`
4. Deploy!

### Docker

```bash
docker build -t lurelands-bridge .
docker run -p 8080:8080 \
  -e SPACETIMEDB_URI=wss://mainnet.spacetimedb.com \
  -e SPACETIMEDB_MODULE=lurelands \
  lurelands-bridge
```

