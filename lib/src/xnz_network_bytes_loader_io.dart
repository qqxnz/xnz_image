import 'dart:typed_data';

import 'package:xnz_image_core/xnz_image_core.dart';

Future<Uint8List> xnzLoadNetworkBytesImpl(
  Uri uri, {
  Map<String, String>? headers,
  XNZCacheKeyStrategy cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
}) async {
  final request = XNZUrlRequest(
    uri.toString(),
    headers: headers,
    cacheKeyStrategy: cacheKeyStrategy,
  );
  final bytes = await XNZImageDownloader.downloadImageDataAndCache(
    request,
  );
  if (bytes == null) {
    throw StateError('Failed to load network bytes: $uri');
  }
  return bytes;
}
