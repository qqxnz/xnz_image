import 'dart:typed_data';

import 'xnz_network_bytes_loader_stub.dart'
    if (dart.library.io) 'xnz_network_bytes_loader_io.dart';

Future<Uint8List> xnzLoadNetworkBytes(
  Uri uri, {
  Map<String, String>? headers,
  bool includeHeadersInCacheKey = false,
}) {
  return xnzLoadNetworkBytesImpl(
    uri,
    headers: headers,
    includeHeadersInCacheKey: includeHeadersInCacheKey,
  );
}
