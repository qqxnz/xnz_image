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
  xnz_image: ^0.2.2
```

### 2) 可选扩展包

```yaml
dependencies:
  xnz_image: ^0.2.2
  xnz_image_svg: ^0.2.2
  xnz_image_avif: ^0.2.2
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

## 日志规范

运行期日志已统一为以下格式：

- `[module][action]`
- `[module][action][key=value,...]`

示例：

```text
[XNZImageDownloader][task_start][requestKey=...,url=https://...]
```

建议在内部/扩展实现中优先使用 `XNZImageLogs.event(module, action, fields: {...})`。
`XNZImageLogs.setInterceptor(...)` 支持两种拦截器签名：

- `void Function(String tag, String message)`（兼容旧写法）
- `bool Function(String tag, String message)`（返回 `true` 表示拦截默认输出）

### 按来源可观测事件

- Network（`XNZNetworkImage` / `XNZNetworkImageProvider`）
  - 加载状态：`load_status_downloading`、`load_status_complete`、`load_status_failed`
  - 缓存路径：`get_memory_cache_hit|miss`、`get_disk_cache_hit|miss`
  - 下载路径：`task_start`、`task_complete`、`task_failed`、`task_reuse_shared`
  - 解码路径：`decode_probe`、`decode_success`、`decode_failed`、`decode_failed_final`
- Memory（`XNZMemoryImage` / `XNZMemoryImageProvider`）
  - 组件链路：`build_start`、`resolve_complete`、`display_failed`
  - 解码链路：`decode_probe`、`decode_success`、`decode_failed`、`load_failed`
- File（`XNZFileImage` / `XNZFileImageProvider`）
  - 组件链路：`build_start`、`resolve_complete`、`display_failed`
  - 解码链路：`decode_probe`、`decode_success`、`decode_failed`、`load_failed`
- Asset（`XNZAssetImage` / `XNZAssetImageProvider`）
  - 组件链路：`build_start`、`resolve_complete`、`display_failed`
  - 解码链路：`decode_probe`、`decode_success`、`decode_failed`、`load_failed`

说明：

- `download_*` 与 network 缓存命中/未命中事件仅适用于网络来源。
- `decode_probe` 会携带 `format` 与 `likelyImage`，便于快速定位格式不匹配问题。
- 委托/自定义 provider 的显示失败会通过 `XNZProxyImageStreamCompleter.display_failed` 输出。

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

## 鉴权网络请求

`XNZNetworkImage` 与 `XNZNetworkImageProvider` 支持可选 `headers`：

```dart
XNZNetworkImage(
  imageUrl: 'https://example.com/private/image.png',
  headers: {'Authorization': 'Bearer <token>'},
  cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders,
)
```

### Cache Key 策略

`cacheKeyStrategy` 控制缓存隔离行为：

- `XNZCacheKeyStrategy.urlOnly`（默认）：cache key 仅使用 URL，公共图命中率更高
- `XNZCacheKeyStrategy.urlAndHeaders`：cache key 使用 URL+headers，适合私有资源

说明：下载中的请求去重（in-flight de-dup）始终使用 URL+headers，避免不同请求头上下文互相复用同一个下载任务。

## 动图播放

`XNZAnimatedImage` 会解码帧并按时间线播放，适用于 GIF / Animated WebP / APNG。
注册 AVIF 扩展后，也可解码播放动画 AVIF。

### 特性

- 时间线同步：`position`、`progress`、`frameIndex`
- 播放控制：`play`、`pause`、`resume`、`replay`
- 回调：`onLoaded`、`onCompleted`
- 循环控制：`loop`
- 错误兜底：`errorBuilder`

### 2026-05-12 维护更新

- 缓存哈希已按运行时分流：
  - Web 继续使用 FNV-1a 32-bit，避免 JS 数值精度语义带来的风险；
  - IO 平台改为 FNV-1a 64-bit，降低缓存 key 碰撞概率。
- IO 平台下的动图网络字节加载已与普通网络图统一到同一下载/缓存链路（`XNZUrlRequest` + `XNZImageDownloader` + `XNZCacheManager`），`cacheKeyStrategy` 行为保持一致。
- AVIF codec key 由对象 hash 派生改为“进程内单调递增整数”，降低原生 decoder key 冲突风险。
- AVIF 异步初始化/解码失败路径增加了防护（初始化错误显式透出，completer 竞争路径更安全）。
- 已新增回归测试：
  - IO 动图统一缓存链路加载；
  - AVIF codec key 单调递增。

### 2026-05-11 维护性更新

- 已优化 memory 场景的动图缓存 key：为 bytes 指纹增加 identity 级缓存，避免频繁全量字节哈希带来的重复 CPU 开销。
- 已将 `XNZAnimatedImage` 的加载/解码/缓存 key/provider 上下文等能力拆分到 `lib/src/animated/` 子模块，降低单文件职责复杂度。
- 已抽取四类基础图片组件的统一 resolve/render helper（`XNZAssetImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZNetworkImage`），减少重复模板代码并提升一致性。
- 对外 API 与使用方式保持兼容，无需业务侧改造。

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
