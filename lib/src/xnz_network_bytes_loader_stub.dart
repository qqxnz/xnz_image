import 'dart:typed_data';

import 'package:xnz_image_core/xnz_image_core.dart';

Future<Uint8List> xnzLoadNetworkBytesImpl(
  Uri uri, {
  Map<String, String>? headers,
}) async {
  final bytes = await XNZImageDownloader.downloadImageDataAndCache(
    uri.toString(),
    headers: headers,
  );
  if (bytes == null) {
    throw StateError('Failed to load network bytes: $uri');
  }
  return bytes;
}
