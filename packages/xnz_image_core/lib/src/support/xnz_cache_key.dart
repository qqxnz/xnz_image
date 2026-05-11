import 'dart:convert';

/// Builds a stable cache key using FNV-1a 32-bit hash.
///
/// We intentionally use a 32-bit variant so the implementation works across
/// native and web (JavaScript) runtimes without precision loss.
String xnzBuildCacheKey(String input) {
  const int fnvOffsetBasis = 0x811c9dc5;
  const int fnvPrime = 0x01000193;
  const int mask32 = 0xffffffff;

  int hash = fnvOffsetBasis;
  for (final b in utf8.encode(input)) {
    hash = (hash ^ b) & mask32;
    hash = (hash * fnvPrime) & mask32;
  }
  return hash.toUnsigned(32).toRadixString(16).padLeft(8, '0');
}
