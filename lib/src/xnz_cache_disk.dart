import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:xnz_image/src/xnz_image_cache_logs.dart';

class XNZDiskCache {
  static XNZDiskCache? _instance;
  static Directory? _cacheDir;
  static const int _maxDiskBytes = 500 * 1024 * 1024;
  static const Duration _maxFileAge = Duration(days: 30);

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

    XNZNetworkImageLogs.log(
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
      // 更新最近使用时间
      await file.setLastModified(DateTime.now());
      return data;
    } catch (e) {
      XNZNetworkImageLogs.log(
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
      await file.writeAsBytes(data, flush: true);
      await file.setLastModified(DateTime.now());
      await _enforceLimits();
    } catch (e) {
      XNZNetworkImageLogs.log(
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
  }

  /// 清空全部缓存
  Future<void> clearAll() async {
    await _init();

    if (_cacheDir!.existsSync()) {
      await _cacheDir!.delete(recursive: true);
      await _cacheDir!.create();
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
        XNZNetworkImageLogs.log(
          'XNZDiskCache',
          'getCurrentBytes stat error file=${entity.path} err=$e',
        );
      }
    }

    return totalBytes;
  }

  Future<void> _enforceLimits() async {
    await _init();
    final now = DateTime.now();
    final entries = <_DiskCacheEntry>[];

    await for (final entity in _cacheDir!.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        entries.add(
          _DiskCacheEntry(
            file: entity,
            size: stat.size,
            modified: stat.modified,
          ),
        );
      } catch (e) {
        XNZNetworkImageLogs.log(
          'XNZDiskCache',
          'stat error file=${entity.path} err=$e',
        );
      }
    }

    // 1) 先按过期时间清理
    for (final entry in entries) {
      if (now.difference(entry.modified) > _maxFileAge) {
        try {
          await entry.file.delete();
        } catch (e) {
          XNZNetworkImageLogs.log(
            'XNZDiskCache',
            'expire delete error file=${entry.file.path} err=$e',
          );
        }
      }
    }

    // 2) 再按 LRU（基于最近修改时间）控制总容量
    final aliveEntries = <_DiskCacheEntry>[];
    int totalBytes = 0;
    for (final entry in entries) {
      if (await entry.file.exists()) {
        aliveEntries.add(entry);
        totalBytes += entry.size;
      }
    }

    if (totalBytes <= _maxDiskBytes) return;

    aliveEntries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in aliveEntries) {
      if (totalBytes <= _maxDiskBytes) break;
      try {
        await entry.file.delete();
        totalBytes -= entry.size;
      } catch (e) {
        XNZNetworkImageLogs.log(
          'XNZDiskCache',
          'lru delete error file=${entry.file.path} err=$e',
        );
      }
    }
  }
}

class _DiskCacheEntry {
  final File file;
  final int size;
  final DateTime modified;

  _DiskCacheEntry({
    required this.file,
    required this.size,
    required this.modified,
  });
}

// import 'dart:typed_data';
// import 'package:path_provider/path_provider.dart';
// import 'package:sqlite3/sqlite3.dart';
// import 'package:xnz_image/src/xnz_image_cache_logs.dart';
//
// class XNZDiskCache {
//   static XNZDiskCache? _instance;
//   static Database? _db;
//
//   static Future<XNZDiskCache> getInstance() async {
//     if (_instance == null) {
//       _instance = XNZDiskCache();
//       await _instance!.init();
//     }
//     return _instance!;
//   }
//
//   // 初始化
//   Future<void> init() async {
//     XNZNetworkImageLogs.log('XNZNetworkImage', 'XNZDiskCache init');
//     final String path = (await getApplicationDocumentsDirectory()).path;
//     String dbPath = '$path/xnz_image_cache.db';
//     if(_db != null){
//       _db!.dispose();
//       _db = null;
//     }
//     _db = sqlite3.open(dbPath);
//     _db!.execute('''
//       CREATE TABLE IF NOT EXISTS image_cache_tb (
//         url TEXT PRIMARY KEY,
//         data BLOB,
//         last_use_time INTEGER
//       )
//     ''');
//   }
//   // 检查缓存是否存在
//   Future<bool> has(String url) async {
//     if (_db == null) {
//       await init();
//     }
//     final ResultSet result = _db!.select(
//       'SELECT 1 FROM image_cache_tb WHERE url = ? LIMIT 1',
//       [url],
//     );
//     return result.isNotEmpty;
//   }
//
//   // 获取缓存中的值，并将它移到最近使用的位置
//   Future<Uint8List?> get(String url) async {
//     if (_db == null) {
//       await init();
//     }
//     final ResultSet result = _db!.select(
//       'SELECT data FROM image_cache_tb WHERE url = ?',
//       [url],
//     );
//     if (result.isEmpty) {
//       return null;
//     }
//     final Uint8List data = result.first['data'] as Uint8List;
//     _db!.execute(
//       'UPDATE image_cache_tb SET last_use_time = ? WHERE url = ?',
//       [DateTime
//           .now()
//           .millisecondsSinceEpoch, url],
//     );
//     return data;
//   }
//
//   // 设置缓存
//   Future<void> set(String url, Uint8List data) async {
//     if (_db == null) {
//       await init();
//     }
//     final ResultSet result = _db!.select(
//       'SELECT data FROM image_cache_tb WHERE url = ?',
//       [url],
//     );
//     if (result.isEmpty) {
//       _db!.execute(
//         'INSERT INTO image_cache_tb (url, data, last_use_time) VALUES (?, ?, ?)',
//         [url, data, DateTime
//             .now()
//             .millisecondsSinceEpoch
//         ],
//       );
//     } else {
//       _db!.execute(
//         'UPDATE image_cache_tb SET data = ?, last_use_time = ? WHERE url = ?',
//         [data, DateTime
//             .now()
//             .millisecondsSinceEpoch, url],
//       );
//     }
//   }
//
//   // 移除缓存中的某项
//   Future<void> remove(String url) async {
//     if (_db == null) {
//       await init();
//     }
//     _db!.execute(
//       'DELETE FROM image_cache_tb WHERE url = ?',
//       [url],
//     );
//   }
//
//   // 清空所有缓存
//   Future<void> clearAll() async {
//     if (_db == null) {
//       await init();
//     }
//     _db!.execute('DELETE FROM image_cache_tb');
//   }
// }
