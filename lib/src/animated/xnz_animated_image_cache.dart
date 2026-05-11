import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'xnz_animated_image_models.dart';

/// In-memory cache for decoded animated images.
@immutable
class XNZAnimatedImageCache {
  /// Creates an animated image cache with bounded entry count.
  XNZAnimatedImageCache({this.maxEntries = 64})
      : assert(maxEntries > 0, 'maxEntries must be greater than zero');

  /// Maximum number of cached animated entries.
  final int maxEntries;

  /// Cached animations indexed by provider-derived key.
  final LinkedHashMap<String, XNZAnimatedImageData> caches =
      LinkedHashMap<String, XNZAnimatedImageData>();

  /// Returns a cached entry and refreshes its recency.
  XNZAnimatedImageData? get(String key) {
    final value = caches.remove(key);
    if (value == null) {
      return null;
    }
    caches[key] = value;
    return value;
  }

  /// Stores a cache entry and evicts least-recently-used entries when needed.
  void set(String key, XNZAnimatedImageData data) {
    final previous = caches.remove(key);
    if (previous != null && !identical(previous, data)) {
      _disposeData(previous);
    }
    caches[key] = data;
    _evictOverflowIfNeeded();
  }

  /// Clears all cached animations and disposes frame images.
  void clear() {
    for (final cached in caches.values) {
      _disposeData(cached);
    }
    caches.clear();
  }

  /// Removes a cached animation and disposes its frame images.
  ///
  /// Returns `true` if the entry existed.
  bool evict(Object key) {
    final removed = caches.remove(key);
    if (removed == null) {
      return false;
    }
    _disposeData(removed);
    return true;
  }

  void _evictOverflowIfNeeded() {
    while (caches.length > maxEntries) {
      final oldestKey = caches.keys.first;
      final removed = caches.remove(oldestKey);
      if (removed != null) {
        _disposeData(removed);
      }
    }
  }

  static void _disposeData(XNZAnimatedImageData data) {
    for (final frame in data.frames) {
      frame.image.dispose();
    }
  }
}
