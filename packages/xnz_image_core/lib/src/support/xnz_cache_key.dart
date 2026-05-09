import 'dart:convert';

/// Builds a stable cache key using FNV-1a 64-bit hash.
String xnzBuildCacheKey(String input) {
  const int fnvOffsetBasis = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  const int mask64 = 0xffffffffffffffff;

  int hash = fnvOffsetBasis;
  for (final b in utf8.encode(input)) {
    hash ^= b;
    hash = (hash * fnvPrime) & mask64;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
