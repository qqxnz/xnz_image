# XNZImage

English | [中文](README.zh-CN.md)

A Flutter image loading package with unified rendering and cache management.
It supports network, memory, file, and asset image sources, and provides an extensible architecture for extra formats.

## Overview

This repository uses a **core + extension** architecture:

- `xnz_image`: main public API (`XNZNetworkImage`, `XNZMemoryImage`, `XNZFileImage`, `XNZAssetImage`, `XNZCacheManager`, etc.)
- `xnz_image_core`: internal capabilities (cache, downloader, extension mechanism)
- `xnz_image_svg`: SVG support extension
- `xnz_image_avif`: AVIF support extension

## Component Reference

For a code-level component behavior analysis (Chinese), see:

- [docs/COMPONENTS.zh-CN.md](docs/COMPONENTS.zh-CN.md)

## Installation

### 1) Base package

```yaml
dependencies:
  xnz_image: ^0.2.5
```

### 2) Optional extensions

```yaml
dependencies:
  xnz_image: ^0.2.5
  xnz_image_svg: ^0.2.5
  xnz_image_avif: ^0.2.5
```

For local development in this monorepo, you may use `path` dependencies.

## Register Extensions

```dart
import 'package:flutter/widgets.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImageLogs.showLogs = true;
  XNZImageMemoryObserver().init();

  XNZImage.support(XNZImageSvg());
  XNZImage.support(XNZImageAvif());

  runApp(const MyApp());
}
```

## Logging

Runtime logs are now normalized to:

- `[module][action]`
- `[module][action][key=value,...]`

Example:

```text
[XNZImageDownloader][task_start][requestKey=...,url=https://...]
```

`XNZImageLogs.event(module, action, fields: {...})` is recommended for internal/extension code.
`XNZImageLogs.setInterceptor(...)` supports both interceptor signatures:

- `void Function(String tag, String message)` (legacy compatible)
- `bool Function(String tag, String message)` (`true` means default output is intercepted)

`XNZImageLogs.logFilter` supports quick category filtering:

- `XNZImageLogFilter.all` (default)
- `XNZImageLogFilter.success`
- `XNZImageLogFilter.failure`

```dart
XNZImageLogs.showLogs = true;
XNZImageLogs.logFilter = XNZImageLogFilter.failure; // only failure logs
```

### Observable Events By Source

- Network (`XNZNetworkImage` / `XNZNetworkImageProvider`)
  - load status: `load_status_downloading`, `load_status_complete`, `load_status_failed`
  - cache path: `get_memory_cache_hit|miss`, `get_disk_cache_hit|miss`
  - download path: `task_start`, `task_complete`, `task_failed`, `task_reuse_shared`
  - decode path: `decode_probe`, `decode_success`, `decode_failed`, `decode_failed_final`
- Memory (`XNZMemoryImage` / `XNZMemoryImageProvider`)
  - widget flow: `build_start`, `resolve_complete`, `display_failed`
  - decode path: `decode_probe`, `decode_success`, `decode_failed`, `load_failed`
- File (`XNZFileImage` / `XNZFileImageProvider`)
  - widget flow: `build_start`, `resolve_complete`, `display_failed`
  - decode path: `decode_probe`, `decode_success`, `decode_failed`, `load_failed`
- Asset (`XNZAssetImage` / `XNZAssetImageProvider`)
  - widget flow: `build_start`, `resolve_complete`, `display_failed`
  - decode path: `decode_probe`, `decode_success`, `decode_failed`, `load_failed`

Notes:

- `download_*` and network cache hit/miss events are network-only by design.
- `decode_probe` includes `format` and `likelyImage`, useful for quick format mismatch diagnosis.
- delegated/custom provider display failures emit `XNZProxyImageStreamCompleter.display_failed`.

## Supported Formats

- Default (`xnz_image` only): common bitmap formats such as `png`, `jpg`, `jpeg`, `gif`, `webp`, `bmp`
- With `xnz_image_svg` registered: `svg`, `svgz`
- With `xnz_image_avif` registered: `avif`, `avifs` (including animated AVIF duration override)

## Basic Widgets

### Network

```dart
XNZNetworkImage(
  imageUrl: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### Memory

```dart
XNZMemoryImage(
  bytes: yourBytes,
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### File

```dart
XNZFileImage(
  file: File('/path/to/local/image.avif'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### Asset

```dart
XNZAssetImage(
  assetName: 'assets/images/banner.avif',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### Use With Flutter `Image`

```dart
Image(
  image: XNZNetworkImageProvider('https://picsum.photos/800/480'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

## Authenticated Network Requests

`XNZNetworkImage` and `XNZNetworkImageProvider` support optional `headers`.

```dart
XNZNetworkImage(
  imageUrl: 'https://example.com/private/image.png',
  headers: {'Authorization': 'Bearer <token>'},
  cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
)
```

### Cache Key Strategy

`cacheKeyStrategy` controls cache isolation behavior:

- `XNZCacheKeyStrategy.urlOnly` (default): URL-only cache key, better hit-rate
- `XNZCacheKeyStrategy.urlAndHeaders`: URL+headers cache key, safer isolation

Note: request de-duplication always uses URL+headers internally to avoid
mixing in-flight downloads from different header contexts.

## Animated Image Playback

`XNZAnimatedImage` decodes frames and plays on a timeline. It is suitable for GIF / Animated WebP / APNG,
and can also decode animated AVIF when AVIF support is registered.

### Highlights

- Timeline sync: `position`, `progress`, `frameIndex`
- Playback control: `play`, `pause`, `resume`, `replay`
- Callbacks: `onLoaded`, `onCompleted`
- Loop control: `loop`
- Error fallback: `errorBuilder`

### Maintenance Updates (2026-05-12)

- Cache-key hashing now uses SHA-256 full-length lowercase hex on all runtimes.
- Animated network bytes loading on IO now goes through the same downloader/cache pipeline as normal network images (`XNZUrlRequest` + `XNZImageDownloader` + `XNZCacheManager`), so `cacheKeyStrategy` behavior is consistent.
- AVIF codec keys now use process-local monotonically increasing integers instead of object-hash-derived values, reducing native decoder key-collision risk.
- AVIF async init/decode guardrails were improved (explicit init error propagation and safer completer handling).
- Added regression tests for:
  - unified IO animated cache-path loading;
  - AVIF codec key monotonicity.

### Maintenance Updates (2026-05-11)

- Optimized animated memory cache-key generation: memory bytes fingerprints are now cached by bytes identity to avoid repeated full-byte hashing on frequent rebuilds.
- Refactored `XNZAnimatedImage` internals into `lib/src/animated/` modules (loader/decoder/cache-key/provider-context/models/controller/cache) to reduce single-file complexity.
- Unified resolve/render flow for `XNZAssetImage`, `XNZMemoryImage`, `XNZFileImage`, and `XNZNetworkImage` via shared helpers, reducing template duplication and future drift risk.
- Public API remains backward compatible.

### Example

```dart
final controller = XNZAnimatedImageController();

XNZAnimatedImage(
  image: XNZNetworkImageProvider('https://example.com/demo.gif'),
  controller: controller,
  autoPlay: true,
  loop: true,
  fit: BoxFit.contain,
  onLoaded: (duration, fps, frameCount) {
    debugPrint('duration=$duration fps=$fps frames=$frameCount');
  },
  onCompleted: (completedLoops) {
    debugPrint('completedLoops=$completedLoops');
  },
  loadingBuilder: (_) => const Center(child: CircularProgressIndicator()),
  errorBuilder: (context, error, stackTrace) {
    return const Center(child: Text('Animated image load failed'));
  },
)
```

## Unified Render Hook (`renderBuilder`)

Use `renderBuilder` to wrap default rendering behavior for bitmap and custom formats:

```dart
XNZNetworkImage(
  imageUrl: url,
  renderBuilder: (context, child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  },
)
```

If `renderBuilder` returns `null`, the widget falls back to default rendering.

## Cache Manager

```dart
import 'dart:typed_data';
import 'package:xnz_image/xnz_image.dart';

Future<void> printCacheUsage() async {
  final cacheManager = XNZCacheManager();
  final memoryBytes = cacheManager.getMemoryCacheBytes();
  final memoryMaxBytes = cacheManager.getMemoryCacheMaxBytes();
  final diskBytes = await cacheManager.getDiskCacheBytes();

  print('Memory cache: $memoryBytes B');
  print('Memory cache max: $memoryMaxBytes B');
  print('Disk cache: $diskBytes B');
}

Future<void> clearAllCache() async {
  await XNZCacheManager().clearAll();
}

Future<void> clearUnusedDiskCache() async {
  // Delete disk cache entries not used for 30 days.
  final deleted = await XNZCacheManager().clearUnusedDiskCache(
    const Duration(days: 30),
  );
  print('Deleted disk cache files: $deleted');
}

Future<void> configureDiskCacheTtl() async {
  final cacheManager = XNZCacheManager();

  // Global default TTL for disk cache writes.
  cacheManager.setDiskCacheDefaultTtl(const Duration(hours: 24));

  // Per-write override.
  await cacheManager.setCache(
    XNZUrlRequest('https://example.com/avatar.png'),
    Uint8List(0),
    ttlOverride: const Duration(hours: 1),
  );
}
```

## Platform Notes

- Web supports `XNZNetworkImage`, `XNZMemoryImage`, `XNZAssetImage`, and `XNZAnimatedImage`.
- Web enables memory cache only (disk cache is disabled).
- Web memory cache defaults to 48MB (native platforms default to 300MB).
- `XNZFileImage` / `XNZFileImageProvider` are not supported on Web and throw `UnsupportedError`.

## Run Example

Minimal pub example:

```bash
flutter run -t example/main.dart
```

More complete demo apps are under:

- `examples/example_bitmap`
- `examples/example_bitmap_svg`
- `examples/example_bitmap_avif`
- `examples/example_bitmap_svg_avif`
