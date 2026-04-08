import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';

class XNZDiskCache {
  static XNZDiskCache? _instance;
  static Directory? _cacheDir;

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
}

// import 'dart:typed_data';
// import 'package:path_provider/path_provider.dart';
// import 'package:sqlite3/sqlite3.dart';
// import 'package:xnz_net_cache_image/src/xnz_image_cache_logs.dart';
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
