import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
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

    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${dir.path}/xnz_image_cache');

    if (!_cacheDir!.existsSync()) {
      _cacheDir!.createSync(recursive: true);
    }

    XNZImageLogs.log(
      'XNZNetworkImage',
      'XNZDiskCache init path=${_cacheDir!.path}',
    );
  }

  /// URL -> 文件名（FNV-1a 64 位哈希，无第三方依赖）
  String _fileNameForUrl(String url) {
    const int fnvOffsetBasis = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    const int mask64 = 0xffffffffffffffff;

    int hash = fnvOffsetBasis;
    for (final b in utf8.encode(url)) {
      hash ^= b;
      hash = (hash * fnvPrime) & mask64;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  File _fileForUrl(String url) {
    return File('${_cacheDir!.path}/${_fileNameForUrl(url)}');
  }

  /// 是否存在
  Future<bool> has(String url) async {
    await _init();
    return _fileForUrl(url).exists();
  }

  /// 读取缓存（并更新最近使用时间）
  Future<Uint8List?> get(String url) async {
    await _init();
    final file = _fileForUrl(url);

    if (!file.existsSync()) {
      return null;
    }

    try {
      final data = await file.readAsBytes();
      await _touchOnReadIfNeeded(file, url);
      return data;
    } catch (e) {
      XNZImageLogs.log(
        'XNZDiskCache',
        'get error url=$url err=$e',
      );
      return null;
    }
  }

  /// 写入缓存
  Future<void> set(String url, Uint8List data) async {
    await _init();
    final file = _fileForUrl(url);

    try {
      // 写入数据会更新文件元信息，避免重复 setLastModified 造成额外 I/O。
      await file.writeAsBytes(data, flush: true);
      _lastTouchAt[url] = DateTime.now();
    } catch (e) {
      XNZImageLogs.log(
        'XNZDiskCache',
        'set error url=$url err=$e',
      );
    }
  }

  /// 移除单个缓存
  Future<void> remove(String url) async {
    await _init();
    final file = _fileForUrl(url);

    if (file.existsSync()) {
      await file.delete();
    }
    _lastTouchAt.remove(url);
  }

  /// 清空全部缓存
  Future<void> clearAll() async {
    await _init();

    if (_cacheDir!.existsSync()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
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
        XNZImageLogs.log(
          'XNZDiskCache',
          'clearUnusedSince failed file=${entity.path} err=$e',
        );
      }
    }

    _lastTouchAt.removeWhere((_, lastTouch) => lastTouch.isBefore(expireBefore));
    XNZImageLogs.log(
      'XNZDiskCache',
      'clearUnusedSince done maxUnused=$maxUnusedDuration deleted=$deletedCount',
    );
    return deletedCount;
  }

  Future<void> _touchOnReadIfNeeded(File file, String url) async {
    final now = DateTime.now();
    final last = _lastTouchAt[url];
    if (last != null && now.difference(last) < _touchInterval) {
      XNZImageLogs.log('XNZDiskCache', 'disk_touch_skipped interval url=$url');
      return;
    }

    try {
      await file.setLastModified(now);
      _lastTouchAt[url] = now;
      XNZImageLogs.log('XNZDiskCache', 'disk_touch_done url=$url');
    } catch (e) {
      XNZImageLogs.log('XNZDiskCache', 'disk_touch_failed url=$url err=$e');
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
        XNZImageLogs.log(
          'XNZDiskCache',
          'getCurrentBytes stat error file=${entity.path} err=$e',
        );
      }
    }

    return totalBytes;
  }
}
