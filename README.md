# XNZImage

面向 Flutter 的图片加载组件，提供网络、内存、文件、Asset 四种图片渲染能力，以及统一缓存管理。

当前仓库采用“核心包 + 可选扩展包”架构：

- `xnz_image`：对外主 API（`XNZNetworkImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZAssetImage`、`XNZCacheManager` 等）
- `xnz_image_core`：内部基础能力（缓存、下载、扩展机制）
- `xnz_image_svg`：SVG 格式支持扩展
- `xnz_image_avif`：AVIF 格式支持扩展

## 包结构与使用原则

- 业务代码始终通过 `xnz_image` 中的组件类使用。
- 需要某种格式支持时，额外引入对应扩展包并在 `main()` 注册。
- 默认不注册扩展时，走 Flutter 原生位图解码链路（png/jpg/webp/gif/bmp 等）。

## 安装

### 1) 基础能力

```yaml
dependencies:
  xnz_image: ^0.1.3
```

### 2) 可选扩展（按需）

```yaml
dependencies:
  xnz_image: ^0.1.3
  xnz_image_svg: ^0.1.0
  xnz_image_avif: ^0.1.0
```

> 在本仓库联调时可使用 `path` 依赖，发布到 pub 后建议改为版本依赖。

## 扩展注册

```dart
import 'package:flutter/widgets.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  XNZImage.support(XNZImageSvg());
  XNZImage.support(XNZImageAvif());

  runApp(const MyApp());
}
```

## 支持格式

- 默认（只引入 `xnz_image`）：`png`、`jpg`、`jpeg`、`gif`、`webp`、`bmp` 等常见位图格式。
- 引入并注册 `xnz_image_svg` 后：支持 `svg`、`svgz`。
- 引入并注册 `xnz_image_avif` 后：支持 `avif`、`avifs`（含动图时长覆盖参数）。

## 组件示例

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
import 'dart:typed_data';

XNZMemoryImage(
  bytes: yourBytes,
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

### 文件图片

```dart
import 'dart:io';

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

### 与 `Image` 组件组合使用

```dart
Image(
  image: XNZNetworkImageProvider('https://picsum.photos/800/480'),
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

## 统一渲染回调（推荐）

新版本提供 `renderBuilder`，用于统一处理位图与自定义渲染（如 SVG）：

```dart
XNZNetworkImage(
  imageUrl: url,
  renderBuilder: (context, resolved) {
    if (resolved.kind == XNZResolvedKind.customWidget) {
      return resolved.widget!;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(
        image: resolved.provider!,
        fit: BoxFit.cover,
      ),
    );
  },
)
```

## 兼容说明

- 旧参数 `imageBuilder` / `svgBuilder` 仍可使用，但已标记为 `@Deprecated`。
- 新代码建议统一迁移到 `renderBuilder`。

## XNZCacheManager 示例

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

- 当前组件不支持 Web 平台。
- 在 Web 端使用相关组件会返回 `UnsupportedError`。

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
