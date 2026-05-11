import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';

class XNZDiskCache {
  static XNZDiskCache? _instance;
  static Directory? _cacheDir;
  static final Map<String, DateTime> _lastTouchAt = <String, DateTime>{};
  static const Duration _touchInterval = Duration(minutes: 10);

  static Future<XNZDiskCache> getInstance() async {
    _instance ??= XNZDiskCache();
    await _instance!._init();
    return _instance!;
  }

  /// 初始化缓存目录
  Future<void> _init() async {
    if (_cacheDir != null) return;

    // Use temporary/cache space for image cache data.
    // Cache entries are re-creatable and should not live in user documents.
    final dir = await getTemporaryDirectory();
    _cacheDir = Directory('${dir.path}/xnz_image_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    XNZImageLogs.event('XNZDiskCache', 'init', fields: {
      'path': _cacheDir!.path,
    });
  }

  File _fileForCacheKey(String cacheKey) {
    return File('${_cacheDir!.path}/$cacheKey');
  }

  /// 是否存在
  Future<bool> has(String cacheKey) async {
    await _init();
    return _fileForCacheKey(cacheKey).exists();
  }

  /// 读取缓存（并更新最近使用时间）
  Future<Uint8List?> get(String cacheKey) async {
    await _init();
    final file = _fileForCacheKey(cacheKey);

    if (!await file.exists()) {
      return null;
    }

    try {
      final data = await file.readAsBytes();
      await _touchOnReadIfNeeded(file, cacheKey);
      return data;
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'get_failed', fields: {
        'cacheKey': cacheKey,
        'error': e,
      });
      return null;
    }
  }

  /// 写入缓存
  Future<void> set(String cacheKey, Uint8List data) async {
    await _init();
    final file = _fileForCacheKey(cacheKey);

    try {
      // 写入数据会更新文件元信息，避免重复 setLastModified 造成额外 I/O。
      await file.writeAsBytes(data, flush: true);
      _lastTouchAt[cacheKey] = DateTime.now();
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'set_failed', fields: {
        'cacheKey': cacheKey,
        'error': e,
      });
    }
  }

  /// 移除单个缓存
  Future<void> remove(String cacheKey) async {
    await _init();
    final file = _fileForCacheKey(cacheKey);

    if (await file.exists()) {
      await file.delete();
    }
    _lastTouchAt.remove(cacheKey);
  }

  /// 清空全部缓存
  Future<void> clearAll() async {
    await _init();

    if (await _cacheDir!.exists()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create(recursive: true);
    }
    _lastTouchAt.clear();
  }

  /// 删除超过 [maxUnusedDuration] 未命中的磁盘缓存文件。
  ///
  /// 返回成功删除的文件数量。
  Future<int> clearUnusedSince(Duration maxUnusedDuration) async {
    await _init();

    if (maxUnusedDuration <= Duration.zero) {
      return 0;
    }

    final expireBefore = DateTime.now().subtract(maxUnusedDuration);
    int deletedCount = 0;

    await for (final entity in _cacheDir!.list(followLinks: false)) {
      if (entity is! File) continue;

      try {
        final stat = await entity.stat();
        if (!stat.modified.isBefore(expireBefore)) {
          continue;
        }
        await entity.delete();
        deletedCount++;
      } catch (e) {
        XNZImageLogs.event('XNZDiskCache', 'clear_unused_failed', fields: {
          'file': entity.path,
          'error': e,
        });
      }
    }

    _lastTouchAt
        .removeWhere((_, lastTouch) => lastTouch.isBefore(expireBefore));
    XNZImageLogs.event('XNZDiskCache', 'clear_unused_done', fields: {
      'maxUnused': maxUnusedDuration,
      'deleted': deletedCount,
    });
    return deletedCount;
  }

  Future<void> _touchOnReadIfNeeded(File file, String cacheKey) async {
    final now = DateTime.now();
    final last = _lastTouchAt[cacheKey];
    if (last != null && now.difference(last) < _touchInterval) {
      XNZImageLogs.event('XNZDiskCache', 'touch_skipped', fields: {
        'cacheKey': cacheKey,
      });
      return;
    }

    try {
      await file.setLastModified(now);
      _lastTouchAt[cacheKey] = now;
      XNZImageLogs.event('XNZDiskCache', 'touch_done', fields: {
        'cacheKey': cacheKey,
      });
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'touch_failed', fields: {
        'cacheKey': cacheKey,
        'error': e,
      });
    }
  }

  /// 当前磁盘缓存占用（字节）
  Future<int> getCurrentBytes() async {
    await _init();
    int totalBytes = 0;

    await for (final entity in _cacheDir!.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        totalBytes += stat.size;
      } catch (e) {
        XNZImageLogs.event('XNZDiskCache', 'stat_failed', fields: {
          'file': entity.path,
          'error': e,
        });
      }
    }

    return totalBytes;
  }
}
