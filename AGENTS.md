# Lurelands - Agent Instructions

This is a multiplayer fishing game built with Flutter

## Project Structure

```
lurelands/
├── apps/
│   └── lurelands/              # Flutter client app (main game)
```

### Apps

The `apps/` folder contains our client applications:

- **lurelands** (Flutter) - This is our main app, the Lurelands fishing game. Built with Flutter and the Flame game engine, it's a multiplayer fishing RPG where players can fish, collect items, and explore the world.

## Asset Management

### Tilesheets & Tiled

- **Do Not Edit Tilesheets**: Tilesheets are managed externally in Tiled. Never modify tilesheet images or Tiled map files directly. If changes are needed, ask the user to make them.
- **Tilesheets Are For Sprite Locations Only**: Tilesheets define where sprites are located in the atlas. All game logic (pricing, display names, descriptions, stats, behaviors) belongs in code, not in tilesheet data.

## Code Quality & Best Practices

### Performance Guidelines

- **Object Pooling**: Reuse game objects (particles, projectiles, temporary entities) instead of creating/destroying them repeatedly. Instantiation is expensive.
- **Efficient Rendering**: Only render what's visible on screen. Use culling for off-screen sprites and tiles.
- **Batch Sprite Rendering**: Group sprites using the same texture atlas to minimize draw calls.
- **Lazy Loading**: Load assets on-demand or during transitions, not all at startup.
- **Cache Expensive Calculations**: Store results of pathfinding, collision detection, and other heavy computations when possible.
- **Avoid Allocations in Game Loop**: Pre-allocate lists, vectors, and other objects. Avoid creating new objects in `update()` or `render()` methods.
- **Use Sprite Atlases**: Combine sprites into texture atlases to reduce texture switching.
- **Profile Regularly**: Use Flutter DevTools and Flame's debug tools to identify bottlenecks.

### Clean & Extensible Architecture

- **Component-Based Design**: Favor composition over inheritance. Game entities should be composed of reusable components (e.g., `MovementComponent`, `HealthComponent`, `InteractableComponent`).
- **Data-Driven Design**: Define game content (items, fish, NPCs, quests, dialogue) in data files (JSON/YAML), not hardcoded in classes. This makes content easy to add and modify.
- **Single Responsibility**: Each class should have one clear purpose. Split large classes into focused, smaller ones.
- **Dependency Injection**: Pass dependencies explicitly rather than using global singletons. Makes testing and refactoring easier.
- **Clear Naming Conventions**: Use descriptive names that reflect purpose (e.g., `FishingRodItem`, `QuestManager`, `PlayerInventoryService`).
- **Separate Game Logic from Rendering**: Keep game state and rules independent from visual representation.

### Stardew Valley-Style Game Patterns

- **Time System**: Implement a robust in-game clock with day/night cycles, seasons, and time-based events. Design it to be pausable and save/load friendly.
- **Tile-Based World**: Use a consistent tile grid system for maps, collision, and object placement.
- **State Machines**: Use state machines for player actions (idle, walking, fishing, talking) and NPC behaviors. Makes complex behaviors manageable.
- **Event System**: Implement a pub/sub event system for decoupled communication between game systems (e.g., `onItemCollected`, `onQuestCompleted`, `onDayEnded`).
- **Save System**: Design save/load from the start. All game state should be serializable. Use versioned save formats for backwards compatibility.
- **Modular Systems**: Keep systems independent (inventory, quests, dialogue, fishing, crafting) so they can be developed and tested in isolation.
- **NPC Schedules**: NPCs should have daily routines and pathfinding. Store schedules as data, not code.
- **Progression Systems**: Design clear unlock paths for areas, items, and features. Track player milestones.

### General Best Practices

- **Test Core Logic**: Unit test game mechanics like inventory management, quest conditions, and damage calculations.
- **Use Constants**: Define magic numbers, durations, and balance values as named constants for easy tuning.
- **Handle Edge Cases**: Account for inventory full, insufficient resources, interrupted actions, and invalid states gracefully.
- **Document Complex Systems**: Add comments explaining *why* for non-obvious logic, especially for game mechanics.
- **Version Control Friendly**: Keep data files and code changes atomic and reviewable.
