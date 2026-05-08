# XNZImage

[English](README.md) | 中文

Flutter 图片加载组件，提供网络、内存、文件、Asset 四种图片渲染能力，并支持统一缓存管理。
该仓库采用 **核心包 + 扩展包** 的架构。

## 仓库结构

- `xnz_image`: 对外主 API（`XNZNetworkImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZAssetImage`、`XNZCacheManager` 等）
- `xnz_image_core`: 内部核心能力（缓存、下载器、扩展机制）
- `xnz_image_svg`: SVG 扩展支持
- `xnz_image_avif`: AVIF 扩展支持

## 安装

### 1) 基础包

```yaml
dependencies:
  xnz_image: ^0.1.10
```

### 2) 可选扩展包

```yaml
dependencies:
  xnz_image: ^0.1.10
  xnz_image_svg: ^0.1.10
  xnz_image_avif: ^0.1.10
```

在当前 monorepo 本地开发时，也可以使用 `path` 依赖。

## 注册扩展

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

- 默认（仅 `xnz_image`）：`png`、`jpg`、`jpeg`、`gif`、`webp`、`bmp` 等常见位图格式
- 注册 `xnz_image_svg` 后：`svg`、`svgz`
- 注册 `xnz_image_avif` 后：`avif`、`avifs`（包括动画 AVIF 时长覆盖能力）

## 基础组件

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

### 配合 Flutter `Image` 使用

```dart
Image(
  image: XNZNetworkImageProvider('https://picsum.photos/800/480'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

## 动图播放

`XNZAnimatedImage` 会解码帧并按时间线播放，适用于 GIF / Animated WebP / APNG。
注册 AVIF 扩展后，也可解码播放动画 AVIF。

### 特性

- 时间线同步：`position`、`progress`、`frameIndex`
- 播放控制：`play`、`pause`、`resume`、`replay`
- 回调：`onLoaded`、`onCompleted`
- 循环控制：`loop`
- 错误兜底：`errorBuilder`

### 示例

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

## 统一渲染钩子 (`renderBuilder`)

使用 `renderBuilder` 包装默认渲染流程（位图与自定义格式都可生效）：

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

如果 `renderBuilder` 返回 `null`，会自动回退到默认渲染。

## 缓存管理

```dart
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
  // 删除 30 天未命中的磁盘缓存。
  final deleted = await XNZCacheManager().clearUnusedDiskCache(
    const Duration(days: 30),
  );
  print('Deleted disk cache files: $deleted');
}
```

## 平台说明

- Web 平台支持 `XNZNetworkImage`、`XNZMemoryImage`、`XNZAssetImage` 与 `XNZAnimatedImage`。
- Web 平台仅启用内存缓存，不启用磁盘缓存。
- Web 内存缓存默认上限 48MB（非 Web 平台默认 300MB）。
- `XNZFileImage` / `XNZFileImageProvider` 在 Web 上不支持，调用时会抛出 `UnsupportedError`。

## 运行示例

最小 pub 示例：

```bash
flutter run -t example/main.dart
```

更完整示例见：

- `examples/example_bitmap`
- `examples/example_bitmap_svg`
- `examples/example_bitmap_avif`
- `examples/example_bitmap_svg_avif`
