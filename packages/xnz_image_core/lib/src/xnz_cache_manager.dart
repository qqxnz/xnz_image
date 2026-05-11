import 'package:flutter/foundation.dart';
import 'package:xnz_image_core/src/xnz_cache_disk.dart';
import 'package:xnz_image_core/src/xnz_cache_memory.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';
import 'package:xnz_image_core/src/support/xnz_url_request.dart';

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
  Future<bool> hasCache(XNZUrlRequest request) async {
    // All cache lookups are keyed by request.cacheKey so callers can choose
    // URL-only or URL+headers behavior at request construction time.
    final cacheKey = request.cacheKey;

    if (memoryCache.has(cacheKey)) {
      XNZImageLogs.event('XNZCacheManager', 'has_cache_memory_hit', fields: {
        'url': request.url,
        'cacheKey': cacheKey,
      });
      return true;
    }

    final diskCache = await XNZDiskCache.getInstance();
    final hasDisk = await diskCache.has(cacheKey);
    if (hasDisk) {
      XNZImageLogs.event('XNZCacheManager', 'has_cache_disk_hit', fields: {
        'url': request.url,
        'cacheKey': cacheKey,
      });
    }
    return hasDisk;
  }

  // 获取缓存（LRU 生效）
  Future<Uint8List?> getCache(XNZUrlRequest request) async {
    final cacheKey = request.cacheKey;

    // 1️⃣ 内存
    final memoryData = memoryCache.get(cacheKey);
    if (memoryData != null) {
      XNZImageLogs.event('XNZCacheManager', 'get_cache_memory_hit', fields: {
        'url': request.url,
        'cacheKey': cacheKey,
      });
      return memoryData;
    }

    // 2️⃣ 磁盘
    final diskCache = await XNZDiskCache.getInstance();
    final diskData = await diskCache.get(cacheKey);
    if (diskData != null) {
      XNZImageLogs.event('XNZCacheManager', 'get_cache_disk_hit', fields: {
        'url': request.url,
        'cacheKey': cacheKey,
      });
      memoryCache.put(cacheKey, diskData);
    }

    return diskData;
  }

  // 设置缓存（内存 + 磁盘）
  Future<void> setCache(XNZUrlRequest request, Uint8List data) async {
    final cacheKey = request.cacheKey;
    memoryCache.put(cacheKey, data);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.set(cacheKey, data);
  }

  // 移除缓存
  Future<void> removeCache(XNZUrlRequest request) async {
    final cacheKey = request.cacheKey;
    memoryCache.remove(cacheKey);

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.remove(cacheKey);
  }

  // 清空所有缓存
  Future<void> clearAll() async {
    memoryCache.clearAll();

    final diskCache = await XNZDiskCache.getInstance();
    await diskCache.clearAll();
  }

  // 只取内存（LRU）
  Uint8List? getMemoryCache(XNZUrlRequest request) {
    final cacheKey = request.cacheKey;
    final data = memoryCache.get(cacheKey);
    if (data != null) {
      XNZImageLogs.event(
        'XNZCacheManager',
        'get_memory_cache_hit',
        fields: {
          'url': request.url,
          'cacheKey': cacheKey,
        },
      );
    }
    return data;
  }

  // 只取磁盘（并写回内存）
  Future<Uint8List?> getDiskCache(XNZUrlRequest request) async {
    final cacheKey = request.cacheKey;
    final diskCache = await XNZDiskCache.getInstance();
    final data = await diskCache.get(cacheKey);
    if (data != null) {
      memoryCache.put(cacheKey, data);
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
