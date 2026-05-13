import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUpAll(() async {
    originalPathProvider = PathProviderPlatform.instance;
    tempDir = await Directory.systemTemp.createTemp('xnz_image_core_ttl_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    final manager = XNZCacheManager();
    manager.setDiskCacheDefaultTtl(null);
    manager.memoryCache.clearAll();

    final disk = await XNZDiskCache.getInstance();
    await disk.clearAll();
  });

  test('ttl=null writes expireAtMs=null and keeps default behavior', () async {
    final manager = XNZCacheManager();
    final request = XNZUrlRequest('https://example.com/ttl-null.png');
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    await manager.setCache(request, bytes);

    final metaFile = _metaFileFor(tempDir, request);
    expect(await metaFile.exists(), isTrue);
    final json =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    expect(json['expireAtMs'], isNull);

    manager.memoryCache.remove(request.cacheKey);
    final diskData = await manager.getDiskCache(request);
    expect(diskData, isNotNull);
    expect(diskData, orderedEquals(bytes));
  });

  test('positive ttl expires on disk reads', () async {
    final manager = XNZCacheManager();
    manager.setDiskCacheDefaultTtl(const Duration(milliseconds: 30));
    final request = XNZUrlRequest('https://example.com/ttl-positive.png');
    final bytes = Uint8List.fromList(<int>[8, 6, 7, 5]);

    await manager.setCache(request, bytes);

    manager.memoryCache.remove(request.cacheKey);
    final beforeExpire = await manager.getDiskCache(request);
    expect(beforeExpire, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    manager.memoryCache.remove(request.cacheKey);
    final afterExpire = await manager.getDiskCache(request);
    expect(afterExpire, isNull);
  });

  test('ttlOverride takes precedence over global default ttl', () async {
    final manager = XNZCacheManager();
    manager.setDiskCacheDefaultTtl(const Duration(days: 1));

    final normalRequest = XNZUrlRequest('https://example.com/ttl-global.png');
    final overrideRequest =
        XNZUrlRequest('https://example.com/ttl-override.png');
    final bytes = Uint8List.fromList(<int>[9, 9, 9]);

    await manager.setCache(normalRequest, bytes);
    await manager.setCache(
      overrideRequest,
      bytes,
      ttlOverride: Duration.zero,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));

    manager.memoryCache.remove(normalRequest.cacheKey);
    manager.memoryCache.remove(overrideRequest.cacheKey);

    final normalData = await manager.getDiskCache(normalRequest);
    final overrideData = await manager.getDiskCache(overrideRequest);

    expect(normalData, isNotNull);
    expect(overrideData, isNull);
  });

  test('negative ttl is normalized to Duration.zero', () async {
    final manager = XNZCacheManager();
    manager.setDiskCacheDefaultTtl(const Duration(milliseconds: -5));
    expect(manager.diskCacheDefaultTtl, Duration.zero);

    final request = XNZUrlRequest('https://example.com/ttl-negative.png');
    await manager.setCache(request, Uint8List.fromList(<int>[7, 7]));

    await Future<void>.delayed(const Duration(milliseconds: 10));
    manager.memoryCache.remove(request.cacheKey);
    final diskData = await manager.getDiskCache(request);
    expect(diskData, isNull);
  });

  test('meta without expireAtMs remains readable (backward compatible)',
      () async {
    final manager = XNZCacheManager();
    final request = XNZUrlRequest('https://example.com/ttl-legacy-meta.png');
    final bytes = Uint8List.fromList(<int>[1, 3, 5, 7]);

    await manager.setCache(request, bytes);

    final metaFile = _metaFileFor(tempDir, request);
    final json =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    json.remove('expireAtMs');
    await metaFile.writeAsString(jsonEncode(json), flush: true);

    manager.memoryCache.remove(request.cacheKey);
    final diskData = await manager.getDiskCache(request);
    expect(diskData, isNotNull);
    expect(diskData, orderedEquals(bytes));
  });
}

File _metaFileFor(Directory tempDir, XNZUrlRequest request) {
  final ext = _inferExtension(request.url);
  final name = ext == null ? request.cacheKey : '${request.cacheKey}.$ext';
  return File('${tempDir.path}/xnz_image_cache/$name.meta');
}

String? _inferExtension(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.isEmpty) {
    return null;
  }
  final segment = uri.pathSegments.last;
  final dot = segment.lastIndexOf('.');
  if (dot <= 0 || dot == segment.length - 1) {
    return null;
  }
  return segment.substring(dot + 1).toLowerCase();
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}
