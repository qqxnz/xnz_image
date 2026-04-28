# XNZImage

English | [中文](#中文)

A Flutter image loading package with unified rendering and cache management.
It supports network, memory, file, and asset image sources, and provides an extensible architecture for extra formats.

## Overview

This repository uses a **core + extension** architecture:

- `xnz_image`: main public API (`XNZNetworkImage`, `XNZMemoryImage`, `XNZFileImage`, `XNZAssetImage`, `XNZCacheManager`, etc.)
- `xnz_image_core`: internal capabilities (cache, downloader, extension mechanism)
- `xnz_image_svg`: SVG support extension
- `xnz_image_avif`: AVIF support extension

## Installation

### 1) Base package

```yaml
dependencies:
  xnz_image: ^0.1.10
```

### 2) Optional extensions

```yaml
dependencies:
  xnz_image: ^0.1.10
  xnz_image_svg: ^0.1.10
  xnz_image_avif: ^0.1.10
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

## Animated Image Playback

`XNZAnimatedImage` decodes frames and plays on a timeline. It is suitable for GIF / Animated WebP / APNG,
and can also decode animated AVIF when AVIF support is registered.

### Highlights

- Timeline sync: `position`, `progress`, `frameIndex`
- Playback control: `play`, `pause`, `resume`, `replay`
- Callbacks: `onLoaded`, `onCompleted`
- Loop control: `loop`
- Error fallback: `errorBuilder`

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
import 'package:xnz_image/xnz_image.dart';

Future<void> printCacheUsage() async {
  final cacheManager = XNZCacheManager();
  final memoryBytes = cacheManager.getMemoryCacheBytes();
  final diskBytes = await cacheManager.getDiskCacheBytes();

  print('Memory cache: $memoryBytes B');
  print('Disk cache: $diskBytes B');
}

Future<void> clearAllCache() async {
  await XNZCacheManager().clearAll();
}
```

## Platform Notes

- Web is currently not supported.
- Using unsupported paths on Web may throw `UnsupportedError`.

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

---

## 中文

面向 Flutter 的图片加载组件，提供网络、内存、文件、Asset 四种图片渲染能力，以及统一缓存管理。
仓库采用“核心包 + 可选扩展包”架构。

## 概览

- `xnz_image`：对外主 API（`XNZNetworkImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZAssetImage`、`XNZCacheManager` 等）
- `xnz_image_core`：内部基础能力（缓存、下载、扩展机制）
- `xnz_image_svg`：SVG 格式支持扩展
- `xnz_image_avif`：AVIF 格式支持扩展

## 安装

### 1) 基础能力

```yaml
dependencies:
  xnz_image: ^0.1.10
```

### 2) 可选扩展（按需）

```yaml
dependencies:
  xnz_image: ^0.1.10
  xnz_image_svg: ^0.1.10
  xnz_image_avif: ^0.1.10
```

在本仓库联调时可使用 `path` 依赖。

## 扩展注册

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

## 支持格式

- 默认（只引入 `xnz_image`）：`png`、`jpg`、`jpeg`、`gif`、`webp`、`bmp`
- 引入并注册 `xnz_image_svg` 后：`svg`、`svgz`
- 引入并注册 `xnz_image_avif` 后：`avif`、`avifs`（支持 AVIF 动图时长覆盖参数）

## 基础组件示例

### 网络图片

```dart
XNZNetworkImage(
  imageUrl: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### 内存图片

```dart
XNZMemoryImage(
  bytes: yourBytes,
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### 文件图片

```dart
XNZFileImage(
  file: File('/path/to/local/image.avif'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### Asset 图片

```dart
XNZAssetImage(
  assetName: 'assets/images/banner.avif',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### 与 Flutter `Image` 组合

```dart
Image(
  image: XNZNetworkImageProvider('https://picsum.photos/800/480'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

## 动画播放组件

`XNZAnimatedImage` 支持帧解码播放，适用于 GIF / Animated WebP / APNG。
注册 AVIF 扩展后，也可自动处理 AVIF 动图。

### 能力概览

- 精准 UI 同步：`position`、`progress`、`frameIndex`
- 播放控制：`play`、`pause`、`resume`、`replay`
- 回调：`onLoaded`、`onCompleted`
- 循环开关：`loop`
- 异常兜底：`errorBuilder`

### 用法示例

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

## 统一渲染回调（`renderBuilder`）

使用 `renderBuilder` 可以统一包装默认渲染结果：

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

当 `renderBuilder` 返回 `null` 时，会回退到默认渲染。

## 缓存管理

```dart
import 'package:xnz_image/xnz_image.dart';

Future<void> printCacheUsage() async {
  final cacheManager = XNZCacheManager();
  final memoryBytes = cacheManager.getMemoryCacheBytes();
  final diskBytes = await cacheManager.getDiskCacheBytes();

  print('Memory cache: $memoryBytes B');
  print('Disk cache: $diskBytes B');
}

Future<void> clearAllCache() async {
  await XNZCacheManager().clearAll();
}
```

## 平台说明

- 当前暂不支持 Web。
- 在 Web 端使用相关能力可能抛出 `UnsupportedError`。

## 运行示例

最小示例：

```bash
flutter run -t example/main.dart
```

完整演示项目在：

- `examples/example_bitmap`
- `examples/example_bitmap_svg`
- `examples/example_bitmap_avif`
- `examples/example_bitmap_svg_avif`
