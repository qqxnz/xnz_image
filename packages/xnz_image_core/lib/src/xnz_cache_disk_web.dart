import 'dart:typed_data';

import 'package:xnz_image_core/src/support/xnz_url_request.dart';

class XNZDiskCache {
  static XNZDiskCache? _instance;

  static Future<XNZDiskCache> getInstance() async {
    _instance ??= XNZDiskCache();
    return _instance!;
  }

  Future<bool> has(XNZUrlRequest request) async => false;

  Future<Uint8List?> get(XNZUrlRequest request) async => null;

  Future<void> set(
    XNZUrlRequest request,
    Uint8List data, {
    int? expireAtMs,
  }) async {}

  Future<void> remove(XNZUrlRequest request) async {}

  Future<void> clearAll() async {}

  Future<int> clearUnusedSince(Duration maxUnusedDuration) async => 0;

  Future<int> getCurrentBytes() async => 0;
}
