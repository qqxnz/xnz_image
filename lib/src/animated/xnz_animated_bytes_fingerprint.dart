import 'dart:typed_data';

final Expando<int> _bytesFingerprintCache =
    Expando<int>('xnz_animated_bytes_fingerprint');

/// Computes a stable fingerprint for [bytes] and caches it by identity.
///
/// This keeps cache-key generation O(1) for repeated calls on the same byte
/// object while preserving full-content sensitivity.
int xnzStableBytesFingerprint(Uint8List bytes) {
  final cached = _bytesFingerprintCache[bytes];
  if (cached != null) {
    return cached;
  }

  // FNV-1a style accumulation: deterministic and fast for large byte arrays.
  var hash = 0x811C9DC5;
  for (final value in bytes) {
    hash ^= value;
    hash = (hash * 0x01000193) & 0x3fffffff;
  }

  _bytesFingerprintCache[bytes] = hash;
  return hash;
}
