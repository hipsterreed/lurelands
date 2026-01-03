/// A simple seeded pseudo-random number generator.
/// 
/// Uses a linear congruential generator (LCG) algorithm to produce
/// deterministic pseudo-random numbers based on a seed value.
/// This is useful for generating consistent procedural content
/// (e.g., pond highlights, grass patches) that remains the same
/// across game sessions.
class SeededRandom {
  int _seed;

  /// Create a seeded random generator with the given seed.
  /// The same seed will always produce the same sequence of numbers.
  SeededRandom(this._seed);

  /// Generate a pseudo-random double between 0.0 (inclusive) and 1.0 (exclusive).
  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
    return _seed / 0x7fffffff;
  }

  /// Generate a pseudo-random boolean (50% chance of true).
  bool nextBool() => nextDouble() > 0.5;

  /// Generate a pseudo-random integer between 0 (inclusive) and [max] (exclusive).
  int nextInt(int max) {
    return (nextDouble() * max).floor();
  }

  /// Generate a pseudo-random double between [min] (inclusive) and [max] (exclusive).
  double nextDoubleInRange(double min, double max) {
    return min + nextDouble() * (max - min);
  }
}

