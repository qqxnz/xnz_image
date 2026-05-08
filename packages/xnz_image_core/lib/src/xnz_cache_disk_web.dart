import 'dart:typed_data';

class XNZDiskCache {
  static XNZDiskCache? _instance;

  static Future<XNZDiskCache> getInstance() async {
    _instance ??= XNZDiskCache();
    return _instance!;
  }

  Future<bool> has(String url) async => false;

  Future<Uint8List?> get(String url) async => null;

  Future<void> set(String url, Uint8List data) async {}

  Future<void> remove(String url) async {}

  Future<void> clearAll() async {}

  Future<int> clearUnusedSince(Duration maxUnusedDuration) async => 0;

  Future<int> getCurrentBytes() async => 0;
}
