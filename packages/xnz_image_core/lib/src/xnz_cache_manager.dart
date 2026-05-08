import 'package:flutter/foundation.dart';
import 'package:xnz_image_core/src/xnz_cache_disk.dart';
import 'package:xnz_image_core/src/xnz_cache_memory.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';

class XNZCacheManager {
  static XNZCacheManager? _instance;
  static const int _bytesPerMb = 1024 * 1024;

  /// 默认内存缓存上限：
  /// - 非 Web：300MB
  /// - Web：48MB（配合浏览器 HTTP 缓存）
  static const int _defaultMaxMemoryBytesNative = 300 * _bytesPerMb;
  static const int _defaultMaxMemoryBytesWeb = 48 * _bytesPerMb;
  static const int _maxMemoryBytes =
      kIsWeb ? _defaultMaxMemoryBytesWeb : _defaultMaxMemoryBytesNative;

  late final XNZMemoryCache<String> memoryCache;

  XNZCacheManager._() {
    memoryCache = XNZMemoryCache<String>(_maxMemoryBytes);
  }

  factory XNZCacheManager() {
    _instance ??= XNZCacheManager._();
    return _instance!;
  }

  // 是否存在缓存（内存优先）
  Future<bool> hasCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);

    if (memoryCache.has(encodedUrl)) {
      XNZImageLogs.log('XNZNetworkImage', 'hasCache $url 内存存在');
      return true;
    }

    final diskCache = await XNZDiskCache.getInstance();
    final hasDisk = await diskCache.has(encodedUrl);
    if (hasDisk) {
      XNZImageLogs.log('XNZNetworkImage', 'hasCache $url 磁盘存在');
    }
    return hasDisk;
  }

  // 获取缓存（LRU 生效）
  Future<Uint8List?> getCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);

    // 1️⃣ 内存
    final memoryData = memoryCache.get(encodedUrl);
    if (memoryData != null) {
      XNZImageLogs.log('XNZNetworkImage', 'getCache $url 内存命中');
      return memoryData;
    }

    // 2️⃣ 磁盘
    final diskCache = await XNZDiskCache.getInstance();
    final diskData = await diskCache.get(encodedUrl);
    if (diskData != null) {
      XNZImageLogs.log('XNZNetworkImage', 'getCache $url 磁盘命中');
      memoryCache.put(encodedUrl, diskData);
    }

    return diskData;
  }

  // 设置缓存（内存 + 磁盘）
  Future<void> setCache(String url, Uint8List data) async {
    final encodedUrl = Uri.encodeComponent(url);
    memoryCache.put(encodedUrl, data);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.set(encodedUrl, data);
  }

  // 移除缓存
  Future<void> removeCache(String url) async {
    final encodedUrl = Uri.encodeComponent(url);
    memoryCache.remove(encodedUrl);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.remove(encodedUrl);
  }

  // 清空所有缓存
  Future<void> clearAll() async {
    memoryCache.clearAll();

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.clearAll();
  }

  // 只取内存（LRU）
  Uint8List? getMemoryCache(String url) {
    final encodedUrl = Uri.encodeComponent(url);
    final data = memoryCache.get(encodedUrl);
    if (data != null) {
      XNZImageLogs.log('XNZNetworkImage', 'getMemoryCache $url 命中');
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

  // 当前内存缓存占用（字节）
  int getMemoryCacheBytes() {
    return memoryCache.currentBytes;
  }

  // 当前内存缓存上限（字节）
  int getMemoryCacheMaxBytes() {
    return memoryCache.maxBytes;
  }

  // 当前磁盘缓存占用（字节）
  Future<int> getDiskCacheBytes() async {
    final diskCache = await XNZDiskCache.getInstance();
    return diskCache.getCurrentBytes();
  }

  // 删除超过指定时间未命中的磁盘缓存，返回删除文件数
  Future<int> clearUnusedDiskCache(Duration maxUnusedDuration) async {
    final diskCache = await XNZDiskCache.getInstance();
    return diskCache.clearUnusedSince(maxUnusedDuration);
  }
}
