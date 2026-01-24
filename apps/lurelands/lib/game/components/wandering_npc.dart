import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';

import 'base_npc.dart';

/// Direction enum for NPC facing
enum NpcDirection { down, left, up, right }

/// State enum for NPC behavior
enum NpcState { idle, walking }

/// NPC that wanders around randomly with animated sprites
class WanderingNpc extends BaseNpc {
  /// Path to the spritesheet asset
  final String spritesheetPath;

  /// Scale factor for the sprite
  final double spriteScale;

  /// Movement speed in pixels per second
  final double moveSpeed;

  /// Minimum time to stay idle before walking
  final double minIdleTime;

  /// Maximum time to stay idle before walking
  final double maxIdleTime;

  /// Minimum time to walk before stopping
  final double minWalkTime;

  /// Maximum time to walk before stopping
  final double maxWalkTime;

  /// Maximum distance NPC can wander from spawn point
  final double wanderRadius;

  // Sprite configuration
  static const int _frameSize = 64;
  static const int _frameCount = 6;
  static const double _walkStepTime = 0.15;
  static const double _idleStepTime = 0.4;

  // Hitbox configuration - ellipse shape matching player style
  static const double _hitboxWidth = 28.0;
  static const double _hitboxHeight = 12.0;
  static const double _hitboxHalfWidth = _hitboxWidth / 2;
  static const double _hitboxHalfHeight = _hitboxHeight / 2;
  static const double _hitboxYOffset = 15.0;
  static const int _ellipseSegments = 12;

  // Animation components
  late SpriteAnimationComponent _animationComponent;
  late Map<NpcDirection, SpriteAnimation> _walkAnimations;
  late Map<NpcDirection, SpriteAnimation> _idleAnimations;

  // Current state
  NpcDirection _currentDirection = NpcDirection.down;
  NpcState _currentState = NpcState.idle;

  // AI state
  final Random _random = Random();
  double _stateTimer = 0;
  double _stateDuration = 0;
  Vector2 _moveDirection = Vector2.zero();

  WanderingNpc({
    required super.position,
    required super.id,
    required super.name,
    required this.spritesheetPath,
    super.title,
    this.spriteScale = 2.5,
    this.moveSpeed = 60.0,
    this.minIdleTime = 2.0,
    this.maxIdleTime = 5.0,
    this.minWalkTime = 1.5,
    this.maxWalkTime = 4.0,
    this.wanderRadius = 150.0,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the spritesheet
    final spritesheet = SpriteSheet(image: await game.images.load(spritesheetPath), srcSize: Vector2.all(_frameSize.toDouble()));

    // Create walk animations for each direction
    // Rows: 0=down, 1=left, 2=up (right mirrors left)
    _walkAnimations = {
      NpcDirection.down: spritesheet.createAnimation(row: 0, stepTime: _walkStepTime, from: 0, to: _frameCount),
      NpcDirection.left: spritesheet.createAnimation(row: 1, stepTime: _walkStepTime, from: 0, to: _frameCount),
      NpcDirection.up: spritesheet.createAnimation(row: 2, stepTime: _walkStepTime, from: 0, to: _frameCount),
      NpcDirection.right: spritesheet.createAnimation(row: 1, stepTime: _walkStepTime, from: 0, to: _frameCount),
    };

    // Create idle animations (slower loop of first 3 walk frames)
    _idleAnimations = {
      NpcDirection.down: spritesheet.createAnimation(row: 0, stepTime: _idleStepTime, from: 0, to: 3),
      NpcDirection.left: spritesheet.createAnimation(row: 1, stepTime: _idleStepTime, from: 0, to: 3),
      NpcDirection.up: spritesheet.createAnimation(row: 2, stepTime: _idleStepTime, from: 0, to: 3),
      NpcDirection.right: spritesheet.createAnimation(row: 1, stepTime: _idleStepTime, from: 0, to: 3),
    };

    // Set component size
    final spriteSize = _frameSize * spriteScale;
    size = Vector2.all(spriteSize);

    // Initialize animation component
    _animationComponent = SpriteAnimationComponent(
      animation: _idleAnimations[NpcDirection.down],
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    await add(_animationComponent);

    // Add ellipse collision hitbox matching player style
    final ellipseCenter = Vector2(
      size.x / 2,
      size.y / 2 + _hitboxYOffset,
    );
    final ellipseVertices = _createEllipseVertices(
      _hitboxHalfWidth,
      _hitboxHalfHeight,
      _ellipseSegments,
      ellipseCenter,
    );
    final hitbox = PolygonHitbox(ellipseVertices);
    await add(hitbox);

    // Start with random idle duration
    _startIdle();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Update AI state timer
    _stateTimer += dt;

    if (_currentState == NpcState.idle) {
      _updateIdle(dt);
    } else {
      _updateWalking(dt);
    }
  }

  void _updateIdle(double dt) {
    // Check if idle time is up
    if (_stateTimer >= _stateDuration) {
      _startWalking();
    }
  }

  void _updateWalking(double dt) {
    // Check if walk time is up
    if (_stateTimer >= _stateDuration) {
      _startIdle();
      return;
    }

    // Calculate new position
    final movement = _moveDirection * moveSpeed * dt;
    final newPosition = position + movement;

    // Check if still within wander radius from spawn
    final distanceFromSpawn = newPosition.distanceTo(basePosition);
    if (distanceFromSpawn > wanderRadius) {
      // Turn around and head back toward spawn
      _moveDirection = (basePosition - position).normalized();
      _updateDirectionFromMovement();
      return;
    }

    // Check for collision at new position
    if (_wouldCollide(newPosition)) {
      // Hit something - pick a new random direction and stop for this frame
      _pickNewDirection();
      return;
    }

    // Apply movement
    position = newPosition;
  }

  /// Check if moving to the given position would cause a collision
  bool _wouldCollide(Vector2 newPos) {
    // Calculate hitbox center at the new position
    // NPC uses Anchor.bottomCenter, so position.y is at the bottom
    final hitboxCenterX = newPos.x;
    final hitboxCenterY = newPos.y - size.y / 2 + _hitboxYOffset;

    // Check multiple points around the hitbox edge
    final checkPoints = [
      Offset(hitboxCenterX, hitboxCenterY), // Center
      Offset(hitboxCenterX + _hitboxHalfWidth * 0.8, hitboxCenterY), // Right
      Offset(hitboxCenterX - _hitboxHalfWidth * 0.8, hitboxCenterY), // Left
      Offset(hitboxCenterX, hitboxCenterY + _hitboxHalfHeight * 0.8), // Bottom
      Offset(hitboxCenterX, hitboxCenterY - _hitboxHalfHeight * 0.8), // Top
    ];

    // Check tile/layer collisions
    for (final point in checkPoints) {
      if (game.isCollisionAt(point.dx, point.dy)) {
        return true;
      }
    }

    // Check tree collisions
    const npcHitboxRadius = (_hitboxHalfWidth + _hitboxHalfHeight) / 2;
    for (final tree in game.trees) {
      final treePos = tree.hitboxWorldPosition;
      final treeRadius = tree.hitboxRadius;

      final dx = hitboxCenterX - treePos.x;
      final dy = hitboxCenterY - treePos.y;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance < npcHitboxRadius + treeRadius) {
        return true;
      }
    }

    return false;
  }

  /// Pick a new random direction (used when hitting collision)
  void _pickNewDirection() {
    final angle = _random.nextDouble() * 2 * pi;
    _moveDirection = Vector2(cos(angle), sin(angle));

    // Bias toward spawn if far away
    final distanceFromSpawn = position.distanceTo(basePosition);
    if (distanceFromSpawn > wanderRadius * 0.3) {
      final toSpawn = (basePosition - position).normalized();
      _moveDirection = (_moveDirection + toSpawn * 2).normalized();
    }

    _updateDirectionFromMovement();
    _updateAnimation();
  }

  void _startIdle() {
    _currentState = NpcState.idle;
    _stateTimer = 0;
    _stateDuration = minIdleTime + _random.nextDouble() * (maxIdleTime - minIdleTime);
    _moveDirection = Vector2.zero();
    _updateAnimation();
  }

  void _startWalking() {
    _currentState = NpcState.walking;
    _stateTimer = 0;
    _stateDuration = minWalkTime + _random.nextDouble() * (maxWalkTime - minWalkTime);

    // Pick a random direction
    final angle = _random.nextDouble() * 2 * pi;
    _moveDirection = Vector2(cos(angle), sin(angle));

    // If far from spawn, bias direction toward spawn
    final distanceFromSpawn = position.distanceTo(basePosition);
    if (distanceFromSpawn > wanderRadius * 0.5) {
      final toSpawn = (basePosition - position).normalized();
      _moveDirection = (_moveDirection + toSpawn).normalized();
    }

    _updateDirectionFromMovement();
    _updateAnimation();
  }

  void _updateDirectionFromMovement() {
    if (_moveDirection.length < 0.1) return;

    final absX = _moveDirection.x.abs();
    final absY = _moveDirection.y.abs();

    if (absX > absY) {
      _currentDirection = _moveDirection.x > 0 ? NpcDirection.right : NpcDirection.left;
    } else {
      _currentDirection = _moveDirection.y > 0 ? NpcDirection.down : NpcDirection.up;
    }
  }

  void _updateAnimation() {
    final SpriteAnimation targetAnimation;

    if (_currentState == NpcState.idle) {
      targetAnimation = _idleAnimations[_currentDirection]!;
    } else {
      targetAnimation = _walkAnimations[_currentDirection]!;
    }

    if (_animationComponent.animation != targetAnimation) {
      _animationComponent.animation = targetAnimation;
      _animationComponent.animationTicker?.reset();
    }

    // Handle horizontal flip for right direction
    final shouldFlip = _currentDirection == NpcDirection.right;
    if (_animationComponent.isFlippedHorizontally != shouldFlip) {
      _animationComponent.flipHorizontally();
    }
  }

  /// Creates vertices for an ellipse polygon approximation
  static List<Vector2> _createEllipseVertices(
    double halfWidth,
    double halfHeight,
    int segments,
    Vector2 center,
  ) {
    final vertices = <Vector2>[];
    for (int i = 0; i < segments; i++) {
      final angle = (2 * pi * i) / segments;
      vertices.add(Vector2(
        center.x + halfWidth * cos(angle),
        center.y + halfHeight * sin(angle),
      ));
    }
    return vertices;
  }

  /// Get the hitbox center position in world coordinates
  /// Note: NPC uses Anchor.bottomCenter, so position.y is at the bottom
  Vector2 get hitboxWorldPosition => Vector2(
    position.x,
    position.y - size.y / 2 + _hitboxYOffset,
  );

  /// Get the hitbox half-width for collision detection
  double get hitboxHalfWidth => _hitboxHalfWidth;

  /// Get the hitbox half-height for collision detection
  double get hitboxHalfHeight => _hitboxHalfHeight;
}

// ============================================================================
// Specific NPC Types
// ============================================================================

/// Lumberjack NPC
class LumberjackNpc extends WanderingNpc {
  LumberjackNpc({required super.position, required super.id, String name = 'Jack'})
    : super(name: name, title: 'Lumberjack', spritesheetPath: 'characters/lumberjack_male.png');
}

/// Miner NPC
class MinerNpc extends WanderingNpc {
  MinerNpc({required super.position, required super.id, String name = 'Dusty'})
    : super(name: name, title: 'Miner', spritesheetPath: 'characters/miner_male.png');
}

/// Male Bartender NPC
class BartenderMaleNpc extends WanderingNpc {
  BartenderMaleNpc({required super.position, required super.id, String name = 'Barney'})
    : super(name: name, title: 'Bartender', spritesheetPath: 'characters/bartender_male.png');
}

/// Female Bartender NPC
class BartenderFemaleNpc extends WanderingNpc {
  BartenderFemaleNpc({required super.position, required super.id, String name = 'Bella'})
    : super(name: name, title: 'Bartender', spritesheetPath: 'characters/bartender_female.png');
}

/// Chef NPC (female sprite)
class ChefNpc extends WanderingNpc {
  ChefNpc({required super.position, required super.id, String name = 'Cookie'})
    : super(name: name, title: 'Chef', spritesheetPath: 'characters/chef_female.png');
}

/// Male Farmer NPC
class FarmerMaleNpc extends WanderingNpc {
  FarmerMaleNpc({required super.position, required super.id, String name = 'Hank'})
    : super(name: name, title: 'Farmer', spritesheetPath: 'characters/farmer_male.png');
}

/// Female Farmer NPC
class FarmerFemaleNpc extends WanderingNpc {
  FarmerFemaleNpc({required super.position, required super.id, String name = 'Daisy'})
    : super(name: name, title: 'Farmer', spritesheetPath: 'characters/farmer_female.png');
}
