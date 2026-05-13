import 'xnz_sha256.dart';

/// Builds a stable cache key using SHA-256 full-length lowercase hex.
String xnzBuildCacheKey(String input) {
  return xnzSha256HexOfString(input);
}
