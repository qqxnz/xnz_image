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
  xnz_image: ^0.1.7
```

### 2) 可选扩展（按需）

```yaml
dependencies:
  xnz_image: ^0.1.7
  xnz_image_svg: ^0.1.7
  xnz_image_avif: ^0.1.7
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
  XNZImageLogs.showLogs = true;
  XNZImageMemoryObserver().init();

  XNZImage.support(XNZImageSvg());
  XNZImage.support(XNZImageAvif());

  runApp(const MyApp());
}
```

## 内存压力监听

`XNZImageMemoryObserver` 用于监听系统内存压力事件，在触发时自动清空图片内存缓存，避免 OOM 风险。

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 可选：开启调试日志，便于观察触发时机
  XNZImageLogs.showLogs = true;

  // 建议在应用启动阶段初始化一次
  XNZImageMemoryObserver().init();

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

## 可控动画组件（帧解码播放）

`XNZAnimatedImage` 支持将图片解码为帧并按时间轴播放，适用于 GIF / Animated WebP / APNG，
并可在注册 `XNZImageAvif()` 后自动处理 AVIF 动图。

### 能力概览

- 精准 UI 同步：`position` / `progress` / `frameIndex`
- 播放控制：`play / pause / resume / replay`
- 回调：`onLoaded` / `onCompleted`
- 循环开关：`loop`
- 异常兜底：`errorBuilder`

### 基础用法

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

### 控制器联动示例

```dart
IconButton(
  onPressed: controller.play,
  icon: const Icon(Icons.play_arrow),
);
IconButton(
  onPressed: controller.pause,
  icon: const Icon(Icons.pause),
);
IconButton(
  onPressed: controller.replay,
  icon: const Icon(Icons.replay),
);
```

```dart
AnimatedBuilder(
  animation: controller,
  builder: (context, _) {
    return Text(
      'frame=${controller.frameIndex} '
      'progress=${controller.progress.toStringAsFixed(2)} '
      'position=${controller.position.inMilliseconds}ms',
    );
  },
)
```

### 使用动画组件加载静态图（单帧）

```dart
XNZAnimatedImage(
  image: const XNZAssetImageProvider('assets/tg.png'),
)
```

静态图会按单帧处理，示例层建议展示为 `fps 0` 语义。

### AVIF 动图（自动识别）

注册 AVIF 扩展后，`XNZAnimatedImage` 会通过 `XNZImageSupport` 自动匹配 AVIF 动画解码：

```dart
XNZImage.support(XNZImageAvif());

XNZAnimatedImage(
  image: XNZNetworkImageProvider(
    'https://example.com/demo.avif',
    avifOverrideDurationMs: -1,
  ),
)
```

## 统一渲染回调（推荐）

新版本提供 `renderBuilder`，用于统一处理位图与自定义渲染（如 SVG）。
签名为：

- `Widget? Function(BuildContext, Widget child)`

当 `renderBuilder` 返回 `null` 时，会回退到默认渲染（如 `Image`、`SvgPicture` 等）：

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

直接返回 `child`：

```dart
XNZNetworkImage(
  imageUrl: url,
  renderBuilder: (context, child) => child,
)
```

返回 `null` 使用默认渲染：

```dart
XNZNetworkImage(
  imageUrl: url,
  renderBuilder: (context, child) => null,
)
```

## 兼容说明

- 统一使用 `renderBuilder` 处理位图与自定义渲染。
- 推荐用 `(context, child)` 包裹默认渲染。

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
