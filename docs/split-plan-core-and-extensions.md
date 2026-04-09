# xnz_image 拆分方案（核心包 + 可选扩展包）

相关文档：

- [使用方式示例](./usage-patterns.md)

## 目标

保持外部使用方式不变，继续使用：

- `XNZNetworkImage`
- `XNZMemoryImage`
- `XNZFileImage`
- `XNZAssetImage`

同时将能力拆分为：

- `xnz_image`：对外主 API
- `xnz_image_core`：内部基础能力与扩展机制
- `xnz_image_svg`：SVG 扩展
- `xnz_image_avif`：AVIF 扩展

扩展通过应用层显式注册：

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImage.support(XNZImageSvg());
  XNZImage.support(XNZImageAvif());
  runApp(const MyApp());
}
```

## 依赖关系

1. `xnz_image_core` 不依赖 `flutter_svg` / `flutter_avif*`。
2. `xnz_image` 依赖 `xnz_image_core`。
3. `xnz_image_svg` 依赖 `xnz_image` + `flutter_svg`。
4. `xnz_image_avif` 依赖 `xnz_image` + `flutter_avif_platform_interface` + 平台实现包。

## 文件级改造清单（含类与方法说明）

### A. xnz_image_core

#### 1) `packages/xnz_image_core/pubspec.yaml`

- `name: xnz_image_core`
  - 说明：核心内部能力包，不含具体格式渲染依赖。
- `dependencies`
  - 说明：仅保留缓存/下载依赖（`flutter`、`dio`、`path_provider`）。

#### 2) `packages/xnz_image_core/lib/xnz_image_core.dart`

- 导出缓存/下载/日志文件。
- 导出扩展协议与注册中心文件。

#### 3) `packages/xnz_image_core/lib/src/support/xnz_image_support.dart`（新增）

- `enum XNZImageSourceType { network, memory, file, asset }`
  - 说明：图片来源类型。
- `class XNZImageRequest`
  - 字段：
    - `Uri? uri`：网络/文件/asset 路径。
    - `Uint8List? bytes`：内存字节。
    - `XNZImageSourceType sourceType`：来源。
    - `Map<String, Object?> options`：扩展参数（如 `avifOverrideDurationMs`）。
- `enum XNZImageBuildKind { provider, widget }`
  - 说明：扩展返回位图 provider 或自定义 widget。
- `class XNZImageBuildResult`
  - 字段：
    - `XNZImageBuildKind kind`
    - `ImageProvider? provider`
    - `WidgetBuilder? widgetBuilder`
    - `String format`
- `abstract class XNZImageSupport`
  - 方法：
    - `String get id`：扩展唯一标识。
    - `int get priority`：匹配优先级。
    - `bool canHandle(XNZImageRequest request)`：是否处理。
    - `XNZImageBuildResult? resolve(XNZImageRequest request)`：返回渲染结果。

#### 4) `packages/xnz_image_core/lib/src/support/xnz_image_registry.dart`（新增）

- `class XNZImageRegistry`
  - 方法：
    - `void support(XNZImageSupport support)`：注册扩展；同 `id` 覆盖旧实现。
    - `bool unsupport(String id)`：移除扩展。
    - `void clear()`：清空扩展（测试用途）。
    - `List<XNZImageSupport> get supports`：当前扩展只读列表。
    - `XNZImageBuildResult? resolve(XNZImageRequest request)`：按 `priority` 从高到低匹配。

#### 5) 现有核心文件（保留并继续作为内部支撑能力）

- `packages/xnz_image_core/lib/src/xnz_cache_manager.dart`
- `packages/xnz_image_core/lib/src/xnz_cache_disk.dart`
- `packages/xnz_image_core/lib/src/xnz_cache_memory.dart`
- `packages/xnz_image_core/lib/src/xnz_cache_memory_observer.dart`
- `packages/xnz_image_core/lib/src/xnz_image_downloader.dart`
- `packages/xnz_image_core/lib/src/xnz_image_cache_logs.dart`

### B. xnz_image（主包）

#### 1) `pubspec.yaml`

- 新增依赖：`xnz_image_core`。
- 移除依赖：`flutter_svg`、`flutter_avif_*`。

#### 2) `lib/xnz_image.dart`

- 保留导出：
  - `XNZNetworkImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZAssetImage`
  - `XNZCacheManager` 等外部 API
- 新增导出：
  - `lib/src/xnz_image.dart`
  - `lib/src/xnz_resolved_image.dart`

#### 3) `lib/src/xnz_image.dart`（新增）

- `class XNZImage`
  - 方法：
    - `static void support(XNZImageSupport support)`：注册扩展。
    - `static bool unsupport(String id)`：卸载扩展。
    - `static void clearSupports()`：清空扩展（测试/重置）。
    - `static List<XNZImageSupport> get supports`：当前扩展视图。
  - 说明：内部转发到 `XNZImageRegistry`。

#### 4) `lib/src/xnz_resolved_image.dart`（新增）

- `enum XNZResolvedKind { bitmapProvider, customWidget }`
- `class XNZResolvedImage`
  - 字段：
    - `XNZResolvedKind kind`
    - `ImageProvider? provider`
    - `Widget? widget`
    - `String format`
    - `Object? meta`
- `typedef XNZRenderBuilder = Widget Function(BuildContext, XNZResolvedImage)`
  - 说明：统一特殊渲染回调。

#### 5) 四个组件文件（修改，入口不变）

- `lib/src/xnz_network_image.dart`
- `lib/src/xnz_memory_image.dart`
- `lib/src/xnz_file_image.dart`
- `lib/src/xnz_asset_image.dart`

每个文件新增/调整：

- 新增参数：`XNZRenderBuilder? renderBuilder`。
- 兼容参数：`imageBuilder` / `svgBuilder` 保留并 `@Deprecated`。
- 私有方法建议：
  - `_buildRequest()`：构造 `XNZImageRequest`。
  - `_resolveBySupports()`：调用 registry 获取 `XNZImageBuildResult`。
  - `_toResolvedImage()`：转换为 `XNZResolvedImage`。
  - `_defaultRender()`：默认渲染（provider -> `Image`，widget -> 直接返回）。
- 行为：
  - 有 `renderBuilder` 时统一走 `renderBuilder`。
  - 无 `renderBuilder` 时走默认渲染。

#### 6) 四个 Provider 文件（修改）

- `lib/src/xnz_network_image_provider.dart`
- `lib/src/xnz_memory_image_provider.dart`
- `lib/src/xnz_file_image_provider.dart`
- `lib/src/xnz_asset_image_provider.dart`

调整说明：

- 删除 AVIF 直接分支和对 AVIF 私有实现的硬耦合。
- 保留基础位图路径与缓存逻辑。

#### 7) 从主包迁出/删除格式实现文件

- 删除：`lib/src/xnz_svg.dart`
- 删除：`lib/src/xnz_memory_avif_image_provider.dart`

### C. xnz_image_svg（SVG 扩展包）

#### 1) `packages/xnz_image_svg/pubspec.yaml`（新增）

- 依赖：`xnz_image`、`flutter_svg`。

#### 2) `packages/xnz_image_svg/lib/xnz_image_svg.dart`（新增）

- 导出 `XNZImageSvg`。

#### 3) `packages/xnz_image_svg/lib/src/xnz_image_svg_support.dart`（新增）

- `class XNZImageSvg implements XNZImageSupport`
  - `id => "svg"`
  - `priority`：高于默认位图。
  - `canHandle(request)`：识别 `.svg/.svgz` 或 svg 字节。
  - `resolve(request)`：返回 `XNZImageBuildResult(kind: widget, ...)`。

#### 4) `packages/xnz_image_svg/lib/src/xnz_svg_utils.dart`（新增）

- 方法：
  - `bool isLikelySvgPath(String path)`
  - `bool isSvgBytes(Uint8List bytes)`
  - `ColorFilter? svgColorFilterFromColor(Color? color)`

### D. xnz_image_avif（AVIF 扩展包）

#### 1) `packages/xnz_image_avif/pubspec.yaml`（新增）

- 依赖：`xnz_image` + `flutter_avif_platform_interface` + 平台包。

#### 2) `packages/xnz_image_avif/lib/xnz_image_avif.dart`（新增）

- 导出 `XNZImageAvif`。

#### 3) `packages/xnz_image_avif/lib/src/xnz_image_avif_support.dart`（新增）

- `class XNZImageAvif implements XNZImageSupport`
  - `id => "avif"`
  - `canHandle(request)`：识别 `.avif/.avifs` 或 avif 字节头。
  - `resolve(request)`：返回 `XNZImageBuildResult(kind: provider, ...)`。

#### 4) `packages/xnz_image_avif/lib/src/xnz_memory_avif_image_provider.dart`（新增）

- 从主包迁移 AVIF provider 实现。
- 关键方法：
  - `obtainKey`
  - `loadImage` / `loadBuffer`
  - 多帧调度与 decoder 生命周期管理方法。

### E. 示例与文档

#### 1) `example/pubspec.yaml`

- 增加 path 依赖：`xnz_image_svg`、`xnz_image_avif`。

#### 2) `example/lib/main.dart`

- 在 `runApp` 之前注册：
  - `XNZImage.support(XNZImageSvg())`
  - `XNZImage.support(XNZImageAvif())`

#### 3) `README.md`

- 新增章节：
  - 默认仅 `xnz_image`
  - 按需引入扩展并注册
  - `renderBuilder` 统一回调
  - 旧 `imageBuilder/svgBuilder` 迁移说明

### F. 测试

#### 1) `test/xnz_image_registry_test.dart`（新增）

- 用例：
  - 幂等/覆盖注册
  - 优先级匹配
  - `unsupport`/`clear` 行为

#### 2) `test/xnz_net_cache_image_test.dart`（修改）

- 用例：
  - 未注册扩展时行为
  - 注册 svg/avif 后行为

## 兼容策略

1. 先发布带兼容层版本：
   - 新增 `renderBuilder`
   - 保留 `imageBuilder` / `svgBuilder`（标记 `@Deprecated`）
2. 观察 1~2 个小版本后再移除旧回调。
3. `XNZImage.support` 保证幂等，重复注册同 `id` 采用覆盖策略。

## 建议实施顺序

1. 先完成 `xnz_image_core` 协议与 registry。
2. 主包改造成“通过 registry 分发格式能力”。
3. 迁移 SVG 到 `xnz_image_svg`。
4. 迁移 AVIF 到 `xnz_image_avif`。
5. 更新 example + README + tests。
