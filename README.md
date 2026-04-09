# XNZImage

一个面向 Flutter 的图片加载组件，提供网络、内存、文件、Asset 四种图片渲染能力，并内置 AVIF 解码与缓存管理，同时支持 SVG 渲染。

Flutter 组件模版工程，包含：

- 组件库代码（`lib/`）
- 组件测试（`test/`）
- 可直接运行的 Demo（`example/`）


## 支持图片格式

- `avif`、`avifs`：组件内置 AVIF 解码路径（含动图时长控制能力）。
- `svg`、`svgz`：组件层自动识别并走 `flutter_svg` 渲染路径（`XNZNetworkImage` / `XNZMemoryImage` / `XNZFileImage` / `XNZAssetImage`）。
- 其他常见格式：`png`、`jpg`、`jpeg`、`gif`、`webp`、`bmp` 等，走 Flutter 原生 `ImageCodec` 解码（具体以目标平台解码能力为准）。

## 平台支持

- 当前组件不支持 Web 平台。
- 在 Web 端使用 `XNZNetworkImage` / `XNZMemoryAvifImage` 会返回不支持错误（`UnsupportedError`）。

## 组件说明及特点

- `XNZNetworkImage`：网络图片组件，内置内存 + 磁盘双层缓存；支持占位图、下载进度、失败态回调，以及连接/发送/接收超时配置。
- `XNZNetworkImageProvider`：可直接配合 Flutter `Image` 使用的网络 `ImageProvider`，保留缓存与下载能力，便于融入已有渲染链路。
- `XNZMemoryImage` / `XNZMemoryImageProvider`：基于字节流渲染，自动识别 AVIF；适合加密解密后、预下载后或本地内存数据的展示。
- `XNZFileImage` / `XNZFileImageProvider`：基于本地文件渲染，支持与 `Image` 组件组合使用，方便处理相册、下载目录等场景。
- `XNZAssetImage` / `XNZAssetImageProvider`：基于 Asset 渲染，支持 `bundle` / `package` 参数，可直接接入 Flutter `Image`。
- `XNZMemoryAvifImage`：轻量 AVIF 内存解码路径，支持多帧 AVIF（`avifs`）播放与时长覆盖（`avifOverrideDurationMs`）。
- `XNZCacheManager`：统一缓存管理入口，支持缓存读写、删除、清空，以及内存/磁盘占用统计。

> 说明：`ImageProvider` 系列（如 `XNZNetworkImageProvider`）仍按位图/AVIF链路工作；SVG 支持当前在组件 Widget 层提供。

## 组件示例

```dart
XNZNetworkImage(
  imageUrl: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

内存字节流渲染（`XNZMemoryImage`）：

```dart
import 'dart:typed_data';

XNZMemoryImage(
  bytes: yourBytes, // Uint8List
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

内存字节流渲染（`Image + XNZMemoryImageProvider`）：

```dart
import 'dart:typed_data';

Image(
  image: XNZMemoryImageProvider(yourBytes), // Uint8List
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

文件渲染（`XNZFileImage`）：

```dart
import 'dart:io';

XNZFileImage(
  file: File('/path/to/local/image.avif'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

文件渲染（`Image + XNZFileImageProvider`）：

```dart
import 'dart:io';

Image(
  image: XNZFileImageProvider(File('/path/to/local/image.avif')),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

Asset 渲染（`XNZAssetImage`）：

```dart
XNZAssetImage(
  assetName: 'assets/images/banner.avif',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

Asset 渲染（`Image + XNZAssetImageProvider`）：

```dart
Image(
  image: XNZAssetImageProvider('assets/images/banner.avif'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

增强用法（圆角 + 进度 + 失败态）：

```dart
XNZNetworkImage(
  imageUrl: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
  placeholder: const SizedBox(
    width: 300,
    height: 180,
    child: Center(child: CircularProgressIndicator()),
  ),
  progressIndicatorBuilder: (progress) {
    return SizedBox(
      width: 300,
      height: 180,
      child: Center(
        child: CircularProgressIndicator(value: progress),
      ),
    );
  },
  imageBuilder: (context, provider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: provider,
        width: 300,
        height: 180,
        fit: BoxFit.cover,
      ),
    );
  },
  loadFailedBuilder: (url, error) {
    return const SizedBox(
      width: 300,
      height: 180,
      child: Center(child: Text('图片加载失败')),
    );
  },
)
```

## XNZCacheManager 简单使用

```dart
import 'package:xnz_image/xnz_image.dart';

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';

  const units = ['KB', 'MB', 'GB', 'TB'];
  double value = bytes / 1024;
  int unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
}

Future<void> printCacheUsage() async {
  final cacheManager = XNZCacheManager();
  final memoryBytes = cacheManager.getMemoryCacheBytes();
  final diskBytes = await cacheManager.getDiskCacheBytes();

  print('Memory cache: ${formatBytes(memoryBytes)}');
  print('Disk cache: ${formatBytes(diskBytes)}');
}

Future<void> clearAllCache() async {
  await XNZCacheManager().clearAll();
}
```

## 本地运行

```bash
# 根目录
fvm flutter pub get

# 示例工程
cd example
fvm flutter pub get
fvm flutter run
```

如果你不使用 FVM，也可以把 `fvm flutter` 改成 `flutter`。
