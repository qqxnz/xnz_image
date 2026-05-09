import 'dart:typed_data';

import 'package:xnz_image_core/xnz_image_core.dart';

import 'xnz_network_bytes_loader_stub.dart'
    if (dart.library.io) 'xnz_network_bytes_loader_io.dart';

Future<Uint8List> xnzLoadNetworkBytes(
  Uri uri, {
  Map<String, String>? headers,
  XNZCacheKeyStrategy cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
}) {
  return xnzLoadNetworkBytesImpl(
    uri,
    headers: headers,
    cacheKeyStrategy: cacheKeyStrategy,
  );
}
