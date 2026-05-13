import 'package:flutter/foundation.dart';

import 'xnz_cache_key.dart';
import 'xnz_network_url.dart';

/// Strategy used to build cache keys for network requests.
enum XNZCacheKeyStrategy {
  /// Cache key uses URL only.
  urlOnly,

  /// Cache key uses URL + normalized headers.
  urlAndHeaders,
}

/// Immutable network request descriptor used by downloader/cache layers.
class XNZUrlRequest {
  XNZUrlRequest(
    String url, {
    Map<String, String>? headers,
    this.cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
  })  : url = xnzNormalizeNetworkUrl(url),
        headers = Map<String, String>.unmodifiable(_normalizeHeaders(headers));

  /// Normalized URL string.
  final String url;

  /// Canonicalized request headers (lower-cased key, sorted by key/value).
  final Map<String, String> headers;

  /// Cache key generation strategy.
  final XNZCacheKeyStrategy cacheKeyStrategy;

  /// Parsed URI of [url], or null if the URL is invalid.
  Uri? get uri => Uri.tryParse(url);

  /// Request de-duplication key.
  ///
  /// Always includes headers when present to avoid mixing in-flight requests
  /// from different auth/header contexts.
  ///
  /// Header values are represented by a stable digest instead of raw text to
  /// avoid leaking sensitive data into logs.
  late final String requestKey = _buildRequestKey(url, headers);

  /// Cache storage key.
  ///
  /// Uses URL only by default, and includes headers when strategy is
  /// [XNZCacheKeyStrategy.urlAndHeaders].
  ///
  /// This allows callers to keep high hit-ratio by default (`url-only`) and
  /// opt into stronger isolation (`url+headers`) only for private resources.
  String get cacheKey => xnzBuildCacheKey(cacheKeySource);

  /// Canonical source string used to derive [cacheKey].
  String get cacheKeySource =>
      cacheKeyStrategy == XNZCacheKeyStrategy.urlAndHeaders ? requestKey : url;

  static Map<String, String> _normalizeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return const <String, String>{};
    }
    final normalized = headers.entries
        .map((entry) => MapEntry(entry.key.toLowerCase(), entry.value))
        .toList(growable: false)
      ..sort((a, b) {
        final keyCompare = a.key.compareTo(b.key);
        if (keyCompare != 0) {
          return keyCompare;
        }
        return a.value.compareTo(b.value);
      });

    final map = <String, String>{};
    for (final entry in normalized) {
      map[entry.key] = entry.value;
    }
    return map;
  }

  static String _buildRequestKey(String url, Map<String, String> headers) {
    if (headers.isEmpty) {
      return url;
    }
    return '$url|headers:${_headersDigest(headers)}';
  }

  static String _headersDigest(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final entry in headers.entries) {
      buffer
        ..write(entry.key)
        ..write(':')
        ..write(entry.value)
        ..write('|');
    }
    return xnzBuildCacheKey(buffer.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZUrlRequest &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          cacheKeyStrategy == other.cacheKeyStrategy &&
          mapEquals(headers, other.headers);

  @override
  int get hashCode => Object.hash(
        url,
        cacheKeyStrategy,
        Object.hashAll(
          headers.entries
              .map((entry) => Object.hash(entry.key, entry.value))
              .toList(growable: false),
        ),
      );
}
