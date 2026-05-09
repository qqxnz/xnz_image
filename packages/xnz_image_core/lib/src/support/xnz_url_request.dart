import 'package:flutter/foundation.dart';

import 'xnz_cache_key.dart';
import 'xnz_network_url.dart';

/// Immutable network request descriptor used by downloader/cache layers.
class XNZUrlRequest {
  XNZUrlRequest(
    String url, {
    Map<String, String>? headers,
    this.includeHeadersInCacheKey = false,
  })  : url = xnzNormalizeNetworkUrl(url),
        headers = Map<String, String>.unmodifiable(_normalizeHeaders(headers));

  /// Normalized URL string.
  final String url;

  /// Canonicalized request headers (lower-cased key, sorted by key/value).
  final Map<String, String> headers;

  /// Whether cache key includes normalized headers.
  ///
  /// Default `false` means cache key uses URL only.
  final bool includeHeadersInCacheKey;

  /// Parsed URI of [url], or null if the URL is invalid.
  Uri? get uri => Uri.tryParse(url);

  /// Request de-duplication key.
  ///
  /// Always includes headers when present to avoid mixing in-flight requests
  /// from different auth/header contexts.
  String get requestKey {
    if (headers.isEmpty) {
      return url;
    }
    return '$url|headers:${_headersSignature(headers)}';
  }

  /// Cache storage key.
  ///
  /// Uses URL only by default, and includes headers when
  /// [includeHeadersInCacheKey] is true.
  ///
  /// This allows callers to keep high hit-ratio by default (`url-only`) and
  /// opt into stronger isolation (`url+headers`) only for private resources.
  String get cacheKey {
    final source = includeHeadersInCacheKey ? requestKey : url;
    return xnzBuildCacheKey(source);
  }

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

  static String _headersSignature(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '';
    }
    return headers.entries
        .map((entry) => '${entry.key}:${entry.value}')
        .join('|');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZUrlRequest &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          includeHeadersInCacheKey == other.includeHeadersInCacheKey &&
          mapEquals(headers, other.headers);

  @override
  int get hashCode => Object.hash(
        url,
        includeHeadersInCacheKey,
        Object.hashAll(
          headers.entries
              .map((entry) => Object.hash(entry.key, entry.value))
              .toList(growable: false),
        ),
      );
}
