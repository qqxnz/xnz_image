import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:xnz_image_core/src/xnz_image_cache_logs.dart';
import 'package:xnz_image_core/src/support/xnz_cache_key.dart';
import 'package:xnz_image_core/src/support/xnz_url_request.dart';

class XNZDiskCache {
  static XNZDiskCache? _instance;
  static Directory? _cacheDir;
  static final Map<String, DateTime> _lastTouchAt = <String, DateTime>{};
  static const Duration _touchInterval = Duration(minutes: 10);
  static const int _metaSchemaVersion = 1;

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

  _DiskEntryPaths _entryPathsForRequest(XNZUrlRequest request) {
    final cacheKey = request.cacheKey;
    final ext = _inferExtension(request.url);
    final name = ext == null ? cacheKey : '$cacheKey.$ext';
    final dataPath = '${_cacheDir!.path}/$name';
    return _DiskEntryPaths(
      data: File(dataPath),
      meta: File('$dataPath.meta'),
      cacheKey: cacheKey,
    );
  }

  /// 是否存在
  Future<bool> has(XNZUrlRequest request) async {
    await _init();
    final entry = _entryPathsForRequest(request);
    final meta = await _readValidMeta(request, entry, updateTouch: false);
    return meta != null;
  }

  /// 读取缓存（并按节流更新 lastAccessAtMs）
  Future<Uint8List?> get(XNZUrlRequest request) async {
    await _init();
    final entry = _entryPathsForRequest(request);
    final meta = await _readValidMeta(request, entry, updateTouch: true);
    if (meta == null) {
      return null;
    }

    try {
      final data = await entry.data.readAsBytes();
      if (meta.contentLength != data.length) {
        XNZImageLogs.event('XNZDiskCache', 'get_length_mismatch', fields: {
          'cacheKey': entry.cacheKey,
          'expected': meta.contentLength,
          'actual': data.length,
        });
        await _cleanupBrokenEntry(entry);
        return null;
      }
      return data;
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'get_failed', fields: {
        'cacheKey': entry.cacheKey,
        'error': e,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }
  }

  /// 写入缓存（data + meta）
  Future<void> set(
    XNZUrlRequest request,
    Uint8List data, {
    int? expireAtMs,
  }) async {
    await _init();
    final entry = _entryPathsForRequest(request);
    final now = DateTime.now();
    final dataTmp =
        File('${entry.data.path}.tmp.$pid.${now.microsecondsSinceEpoch}');
    final metaTmp =
        File('${entry.meta.path}.tmp.$pid.${now.microsecondsSinceEpoch}');

    final source = request.cacheKeySource;
    final meta = _XNZDiskCacheMeta(
      schemaVersion: _metaSchemaVersion,
      hashAlgo: 'sha256-hex',
      cacheKey: entry.cacheKey,
      cacheKeyStrategy: request.cacheKeyStrategy.name,
      keySourceChecksum: xnzBuildCacheKey(source),
      originalUrl: request.url,
      requestHeaders: request.headers,
      createdAtMs: now.millisecondsSinceEpoch,
      lastAccessAtMs: now.millisecondsSinceEpoch,
      expireAtMs: expireAtMs,
      contentLength: data.length,
      ext: _inferExtension(request.url),
    );

    try {
      await dataTmp.writeAsBytes(data, flush: true);
      await metaTmp.writeAsString(
        jsonEncode(meta.toJson()),
        flush: true,
      );

      await dataTmp.rename(entry.data.path);
      await metaTmp.rename(entry.meta.path);
      _lastTouchAt[entry.cacheKey] = now;
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'set_failed', fields: {
        'cacheKey': entry.cacheKey,
        'error': e,
      });
      await _deleteIfExists(dataTmp);
      await _deleteIfExists(metaTmp);
    }
  }

  /// 移除单个缓存
  Future<void> remove(XNZUrlRequest request) async {
    await _init();
    final entry = _entryPathsForRequest(request);
    await _deleteIfExists(entry.data);
    await _deleteIfExists(entry.meta);
    _lastTouchAt.remove(entry.cacheKey);
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

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expireBeforeMs = nowMs - maxUnusedDuration.inMilliseconds;
    int deletedCount = 0;

    await for (final entity in _cacheDir!.list(followLinks: false)) {
      if (entity is! File) continue;

      final path = entity.path;
      if (_isTmpPath(path)) {
        // Cleanup stale temp files from interrupted writes.
        try {
          final stat = await entity.stat();
          final staleBefore = DateTime.now().subtract(const Duration(hours: 1));
          if (stat.modified.isBefore(staleBefore)) {
            await entity.delete();
          }
        } catch (_) {}
        continue;
      }

      if (!path.endsWith('.meta')) {
        // Remove orphan data file if its paired meta is missing.
        final maybeMeta = File('$path.meta');
        if (!await maybeMeta.exists()) {
          await _deleteIfExists(entity);
          deletedCount++;
        }
        continue;
      }

      try {
        final meta = await _readMetaFile(entity);
        if (meta == null) {
          final entry = _entryPathsFromMetaPath(path);
          await _cleanupBrokenEntry(entry);
          deletedCount++;
          continue;
        }

        final shouldDelete = meta.lastAccessAtMs <= expireBeforeMs ||
            (meta.expireAtMs != null && meta.expireAtMs! <= nowMs);
        if (!shouldDelete) {
          continue;
        }

        final entry = _entryPathsFromMetaPath(path);
        await _cleanupBrokenEntry(entry);
        deletedCount++;
      } catch (e) {
        XNZImageLogs.event('XNZDiskCache', 'clear_unused_failed', fields: {
          'file': entity.path,
          'error': e,
        });
      }
    }

    XNZImageLogs.event('XNZDiskCache', 'clear_unused_done', fields: {
      'maxUnused': maxUnusedDuration,
      'deleted': deletedCount,
    });
    return deletedCount;
  }

  /// 当前磁盘缓存占用（字节）
  Future<int> getCurrentBytes() async {
    await _init();
    int totalBytes = 0;

    await for (final entity in _cacheDir!.list(followLinks: false)) {
      if (entity is! File) continue;
      if (_isTmpPath(entity.path)) continue;
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

  Future<_XNZDiskCacheMeta?> _readValidMeta(
    XNZUrlRequest request,
    _DiskEntryPaths entry, {
    required bool updateTouch,
  }) async {
    if (!await entry.meta.exists() || !await entry.data.exists()) {
      return null;
    }

    final meta = await _readMetaFile(entry.meta);
    if (meta == null) {
      await _cleanupBrokenEntry(entry);
      return null;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (meta.expireAtMs != null && meta.expireAtMs! <= nowMs) {
      XNZImageLogs.event('XNZDiskCache', 'meta_expired', fields: {
        'cacheKey': entry.cacheKey,
        'expireAtMs': meta.expireAtMs,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }

    if (meta.schemaVersion != _metaSchemaVersion ||
        meta.hashAlgo != 'sha256-hex') {
      XNZImageLogs.event('XNZDiskCache', 'meta_schema_mismatch', fields: {
        'cacheKey': entry.cacheKey,
        'schemaVersion': meta.schemaVersion,
        'hashAlgo': meta.hashAlgo,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }

    final expectedKeyChecksum = xnzBuildCacheKey(request.cacheKeySource);
    final bool keyMatched = meta.cacheKey == entry.cacheKey &&
        meta.keySourceChecksum == expectedKeyChecksum &&
        meta.originalUrl == request.url &&
        meta.cacheKeyStrategy == request.cacheKeyStrategy.name;
    if (!keyMatched) {
      XNZImageLogs.event('XNZDiskCache', 'meta_key_mismatch', fields: {
        'cacheKey': entry.cacheKey,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }

    if (request.cacheKeyStrategy == XNZCacheKeyStrategy.urlAndHeaders &&
        !_mapEquals(meta.requestHeaders, request.headers)) {
      XNZImageLogs.event('XNZDiskCache', 'meta_headers_mismatch', fields: {
        'cacheKey': entry.cacheKey,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }

    final stat = await entry.data.stat();
    if (stat.size != meta.contentLength) {
      XNZImageLogs.event('XNZDiskCache', 'meta_length_mismatch', fields: {
        'cacheKey': entry.cacheKey,
        'expected': meta.contentLength,
        'actual': stat.size,
      });
      await _cleanupBrokenEntry(entry);
      return null;
    }

    if (updateTouch) {
      await _touchMetaIfNeeded(entry, meta, nowMs);
    }

    return meta;
  }

  Future<_XNZDiskCacheMeta?> _readMetaFile(File metaFile) async {
    try {
      final text = await metaFile.readAsString();
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) {
        return null;
      }
      return _XNZDiskCacheMeta.fromJson(json);
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'meta_read_failed', fields: {
        'file': metaFile.path,
        'error': e,
      });
      return null;
    }
  }

  Future<void> _touchMetaIfNeeded(
    _DiskEntryPaths entry,
    _XNZDiskCacheMeta meta,
    int nowMs,
  ) async {
    final last = _lastTouchAt[entry.cacheKey];
    if (last != null && DateTime.now().difference(last) < _touchInterval) {
      return;
    }

    if (nowMs - meta.lastAccessAtMs < _touchInterval.inMilliseconds) {
      return;
    }

    final updated = meta.copyWith(lastAccessAtMs: nowMs);
    final tmp = File(
        '${entry.meta.path}.tmp.$pid.${DateTime.now().microsecondsSinceEpoch}');

    try {
      await tmp.writeAsString(jsonEncode(updated.toJson()), flush: true);
      await tmp.rename(entry.meta.path);
      _lastTouchAt[entry.cacheKey] = DateTime.now();
    } catch (e) {
      XNZImageLogs.event('XNZDiskCache', 'touch_failed', fields: {
        'cacheKey': entry.cacheKey,
        'error': e,
      });
      await _deleteIfExists(tmp);
    }
  }

  Future<void> _cleanupBrokenEntry(_DiskEntryPaths entry) async {
    await _deleteIfExists(entry.data);
    await _deleteIfExists(entry.meta);
    _lastTouchAt.remove(entry.cacheKey);
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  _DiskEntryPaths _entryPathsFromMetaPath(String metaPath) {
    final dataPath = metaPath.substring(0, metaPath.length - '.meta'.length);
    final name = dataPath.split(RegExp(r'[/\\\\]')).last;
    final cacheKey = name.split('.').first;
    return _DiskEntryPaths(
      data: File(dataPath),
      meta: File(metaPath),
      cacheKey: cacheKey,
    );
  }

  static bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  static bool _isTmpPath(String path) {
    return path.contains('.tmp.');
  }

  static String? _inferExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }
    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return null;
    }
    final last = segments.last;
    final dot = last.lastIndexOf('.');
    if (dot <= 0 || dot >= last.length - 1) {
      return null;
    }
    final ext = last.substring(dot + 1).toLowerCase();
    final valid = RegExp(r'^[a-z0-9]{1,16}$');
    return valid.hasMatch(ext) ? ext : null;
  }
}

class _DiskEntryPaths {
  const _DiskEntryPaths({
    required this.data,
    required this.meta,
    required this.cacheKey,
  });

  final File data;
  final File meta;
  final String cacheKey;
}

class _XNZDiskCacheMeta {
  const _XNZDiskCacheMeta({
    required this.schemaVersion,
    required this.hashAlgo,
    required this.cacheKey,
    required this.cacheKeyStrategy,
    required this.keySourceChecksum,
    required this.originalUrl,
    required this.requestHeaders,
    required this.createdAtMs,
    required this.lastAccessAtMs,
    required this.expireAtMs,
    required this.contentLength,
    required this.ext,
  });

  final int schemaVersion;
  final String hashAlgo;
  final String cacheKey;
  final String cacheKeyStrategy;
  final String keySourceChecksum;
  final String originalUrl;
  final Map<String, String> requestHeaders;
  final int createdAtMs;
  final int lastAccessAtMs;
  final int? expireAtMs;
  final int contentLength;
  final String? ext;

  factory _XNZDiskCacheMeta.fromJson(Map<String, dynamic> json) {
    final headersRaw = json['requestHeaders'];
    final headers = <String, String>{};
    if (headersRaw is Map) {
      for (final entry in headersRaw.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key is String && value is String) {
          headers[key] = value;
        }
      }
    }

    return _XNZDiskCacheMeta(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? -1,
      hashAlgo: json['hashAlgo'] as String? ?? '',
      cacheKey: json['cacheKey'] as String? ?? '',
      cacheKeyStrategy: json['cacheKeyStrategy'] as String? ?? '',
      keySourceChecksum: json['keySourceChecksum'] as String? ?? '',
      originalUrl: json['originalUrl'] as String? ?? '',
      requestHeaders: headers,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      lastAccessAtMs: (json['lastAccessAtMs'] as num?)?.toInt() ?? 0,
      expireAtMs: (json['expireAtMs'] as num?)?.toInt(),
      contentLength: (json['contentLength'] as num?)?.toInt() ?? -1,
      ext: json['ext'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'hashAlgo': hashAlgo,
      'cacheKey': cacheKey,
      'cacheKeyStrategy': cacheKeyStrategy,
      'keySourceChecksum': keySourceChecksum,
      'originalUrl': originalUrl,
      'requestHeaders': requestHeaders,
      'createdAtMs': createdAtMs,
      'lastAccessAtMs': lastAccessAtMs,
      'expireAtMs': expireAtMs,
      'contentLength': contentLength,
      'ext': ext,
    };
  }

  _XNZDiskCacheMeta copyWith({
    int? lastAccessAtMs,
  }) {
    return _XNZDiskCacheMeta(
      schemaVersion: schemaVersion,
      hashAlgo: hashAlgo,
      cacheKey: cacheKey,
      cacheKeyStrategy: cacheKeyStrategy,
      keySourceChecksum: keySourceChecksum,
      originalUrl: originalUrl,
      requestHeaders: requestHeaders,
      createdAtMs: createdAtMs,
      lastAccessAtMs: lastAccessAtMs ?? this.lastAccessAtMs,
      expireAtMs: expireAtMs,
      contentLength: contentLength,
      ext: ext,
    );
  }
}
