import 'dart:typed_data';
import 'package:xnz_cache_image/xnz_cache_disk.dart';
import 'package:xnz_cache_image/xnz_cache_memory.dart';
import 'package:xnz_cache_image/xnz_image_cache_logs.dart';

class XNZCache {
  static XNZCache? _instance;

  /// 60MB 内存缓存
  static const int _maxMemoryBytes = 60 * 1024 * 1024;

  late final XNZMemoryCache<String> memoryCache;

  XNZCache._() {
    memoryCache = XNZMemoryCache<String>(_maxMemoryBytes);
  }

  factory XNZCache() {
    _instance ??= XNZCache._();
    return _instance!;
  }

  // 是否存在缓存（内存优先）
  Future<bool> hasCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);

    if (memoryCache.has(encodedUrl)) {
      XNZCacheImageLogs.log('XNZCacheImage', 'hasCache $url 内存存在');
      return true;
    }

    final diskCache = await XNZDiskCache.getInstance();
    final hasDisk = await diskCache.has(encodedUrl);
    if (hasDisk) {
      XNZCacheImageLogs.log('XNZCacheImage', 'hasCache $url 磁盘存在');
    }
    return hasDisk;
  }

  // 获取缓存（LRU 生效）
  Future<Uint8List?> getCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);

    // 1️⃣ 内存
    final memoryData = memoryCache.get(encodedUrl);
    if (memoryData != null) {
      XNZCacheImageLogs.log('XNZCacheImage', 'getCache $url 内存命中');
      return memoryData;
    }

    // 2️⃣ 磁盘
    final diskCache = await XNZDiskCache.getInstance();
    final diskData = await diskCache.get(encodedUrl);
    if (diskData != null) {
      XNZCacheImageLogs.log('XNZCacheImage', 'getCache $url 磁盘命中');
      memoryCache.put(encodedUrl, diskData);
    }

    return diskData;
  }

  // 设置缓存（内存 + 磁盘）
  void setCache(String url, Uint8List data) async {
    final encodedUrl = Uri.encodeComponent(url);
    memoryCache.put(encodedUrl, data);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.set(encodedUrl, data);
  }

  // 移除缓存
  void removeCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);
    memoryCache.remove(encodedUrl);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.remove(encodedUrl);
  }

  // 清空所有缓存
  void clearAll() async {
    memoryCache.clearAll();

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.clearAll();
  }

  // 只取内存（LRU）
  Uint8List? getMemoryCache(String url) {
    final encodedUrl = Uri.encodeComponent(url);
    final data = memoryCache.get(encodedUrl);
    if (data != null) {
      XNZCacheImageLogs.log('XNZCacheImage', 'getMemoryCache $url 命中');
    }
    return data;
  }

  // 只取磁盘（并写回内存）
  Future<Uint8List?> getDiskCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);
    final diskCache = await XNZDiskCache.getInstance();
    final data = await diskCache.get(encodedUrl);
    if (data != null) {
      memoryCache.put(encodedUrl, data);
    }
    return data;
  }
}
