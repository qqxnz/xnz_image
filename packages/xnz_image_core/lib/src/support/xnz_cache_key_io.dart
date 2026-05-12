import 'dart:convert';

/// Builds a stable cache key using FNV-1a 64-bit hash on IO platforms.
///
/// VM/native runtimes support full-width integer operations, so using 64-bit
/// reduces collision probability for disk/memory cache keys.
String xnzBuildCacheKey(String input) {
  const int fnvOffsetBasis = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  const int mask64 = 0xffffffffffffffff;

  int hash = fnvOffsetBasis;
  for (final b in utf8.encode(input)) {
    hash = (hash ^ b) & mask64;
    hash = (hash * fnvPrime) & mask64;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
