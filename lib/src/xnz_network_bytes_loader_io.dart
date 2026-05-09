import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

Future<Uint8List> xnzLoadNetworkBytesImpl(
  Uri uri, {
  Map<String, String>? headers,
  XNZCacheKeyStrategy cacheKeyStrategy = XNZCacheKeyStrategy.urlOnly,
}) async {
  // IO loader does not manage cache locally; the option is for API parity.
  final _ = cacheKeyStrategy;
  final httpClient = HttpClient();
  try {
    final request = await httpClient.getUrl(uri);
    headers?.forEach(request.headers.add);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Request failed, statusCode: ${response.statusCode}',
        uri: uri,
      );
    }
    final bytes = await consolidateHttpClientResponseBytes(response);
    return Uint8List.fromList(bytes);
  } finally {
    httpClient.close(force: true);
  }
}
