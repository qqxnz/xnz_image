# XNZImage 组件实现说明（基于源码）

本文档基于当前仓库源码整理，重点解释组件实际行为与参数语义，便于业务接入和问题排查。

## 1. 架构与渲染链路

`xnz_image` 采用「组件层 + Provider 层 + Core 层 + 扩展注册层」架构：

- 组件层：`XNZNetworkImage`、`XNZMemoryImage`、`XNZFileImage`、`XNZAssetImage`、`XNZAnimatedImage`
- Provider 层：各类 `ImageProvider`，负责加载字节并解码
- Core 层：`XNZCacheManager`、`XNZImageDownloader`、`XNZUrlRequest`
- 扩展层：`XNZImage.support(...)` 注册 `XNZImageSupport`，按 `priority` 从高到低解析

统一解析流程：

1. 组件构建 `XNZImageRequest`。
2. 先走 `XNZImageRegistry.resolve(request)`，命中扩展则返回自定义 provider/widget。
3. 未命中时回退内建 provider（位图解码路径）。
4. 可通过 `renderBuilder` 对最终渲染结果做统一包裹。

## 2. 四类基础组件行为

### 2.1 XNZNetworkImage

加载状态枚举：

- `none`：初始状态
- `downloading`：下载中
- `complete`：加载完成
- `failed`：加载失败

实际加载顺序：

1. 查内存缓存（`getMemoryCache`）
2. 查磁盘缓存（`getDiskCache`）
3. 发起下载（`XNZImageDownloaderTask`）
4. 下载成功后回写内存+磁盘缓存

`didUpdateWidget` 会触发重新加载的条件：

- `imageUrl`（规范化后）变化
- `headers` 变化
- `cacheKeyStrategy` 变化
- `sendTimeout` / `receiveTimeout` 变化
- `avifOverrideDurationMs` 变化

补充细节：

- `progressIndicatorBuilder` 仅在下载阶段生效。
- 进度刷新节流为「100ms 或进度变化 >= 1%」。
- `imageUrl` 为空会直接进入 `failed`，错误为 `ArgumentError`。
- 无 `placeholder` 时：若宽高都为空返回 `SizedBox.shrink()`，否则返回指定宽高的 `SizedBox`。

### 2.2 XNZMemoryImage

- 使用 `Uint8List` 作为输入。
- 可通过扩展机制接管（例如 AVIF/SVG 场景）。
- 默认回退为 `XNZMemoryImageProvider` 走 Flutter 位图解码。

### 2.3 XNZFileImage

- IO 平台通过 `File.readAsBytes()` 加载并解码。
- Web 平台不支持，会抛出 `UnsupportedError`。

### 2.4 XNZAssetImage

- 支持 `bundle` 与 `package`。
- `package` 非空时实际资源路径为 `packages/<package>/<assetName>`。
- 同样支持扩展接管与默认位图回退。

## 3. Provider 层关键语义

### 3.1 XNZNetworkImageProvider

- 使用 `XNZUrlRequest` 构建请求描述。
- 当解码失败时会执行一次「删缓存后重试下载+解码」。
- 最后一个监听器移除后，会取消进行中的下载。

注意：`XNZNetworkImageProvider` 本身不暴露超时参数；超时配置在 `XNZNetworkImage` 组件层可用。

### 3.2 XNZMemoryImageProvider

- `bytesFingerprint` 用于动图缓存 key 构建，按 bytes identity 做稳定缓存。
- `==` 比较包含 `bytes`、`scale`、`avifOverrideDurationMs`。

### 3.3 XNZFileImageProvider / XNZAssetImageProvider

- 两者都先尝试扩展接管，再走内建位图解码。
- `==` / `hashCode` 均包含影响解码结果的关键参数（路径、scale、avif 参数等）。

## 4. XNZAnimatedImage 行为说明

### 4.1 播放与状态

`XNZAnimatedImageController` 可观察状态：

- `position`
- `duration`
- `frameIndex`
- `completedLoops`
- `isPlaying`
- `isCompleted`
- `progress`（0.0..1.0）

控制方法：`play` / `pause` / `resume` / `replay`。

### 4.2 解码来源优先级

1. 若扩展在 `XNZImageBuildResult.meta['animatedDecoder']` 提供解码器，则优先使用。
2. 否则走内建 `instantiateImageCodec`。

### 4.3 动图缓存

- 全局缓存：`XNZAnimatedImage.cache`。
- 默认 `maxEntries = 64`，LRU 淘汰。
- 缓存命中后会 clone frame，避免 widget 生命周期释放缓存持有的图像句柄。

### 4.4 循环语义

- `loop = true`：按时间线无限循环。
- `loop = false`：完成首轮后停在最后一帧，`isCompleted = true`。
- `onCompleted` 在每轮结束时触发并携带累计轮次。

## 5. 缓存与请求键策略

### 5.1 XNZUrlRequest 两个键

- `requestKey`：用于下载中的请求去重（始终区分 headers 上下文）
- `cacheKey`：用于缓存命中（由 `cacheKeyStrategy` 决定）

`cacheKeyStrategy`：

- `urlOnly`（默认）：命中率高
- `urlAndHeaders`：隔离更强，适合鉴权资源

实现上 headers 会规范化（key 小写、排序）并做摘要，不直接暴露敏感值。

### 5.2 XNZCacheManager

能力：

- `getCache` / `setCache` / `removeCache` / `clearAll`
- 内存与磁盘占用查询
- 清理长期未使用磁盘缓存
- 配置磁盘缓存默认 TTL（`setDiskCacheDefaultTtl`）

默认内存上限：

- 非 Web：300MB
- Web：48MB

TTL 规则：

- `null`：不过期
- 负数：归一化为 `Duration.zero`
- `ttlOverride` 优先级高于全局默认 TTL

## 6. 日志与可观测性

建议使用 `XNZImageLogs.event(module, action, fields)` 输出结构化日志。

常见排障关注点：

- `*_cache_hit/miss`：缓存命中链路
- `task_*`：下载生命周期
- `decode_*`：解码成败
- `display_failed`：渲染阶段异常

可通过 `XNZImageLogs.logFilter` 仅看成功或失败日志。

## 7. 平台差异与接入建议

平台差异：

- Web 不支持 `XNZFileImage` / `XNZFileImageProvider`
- Web 的 `XNZDiskCache` 为 no-op，仅保留内存缓存行为

接入建议：

1. 私有资源务必使用 `cacheKeyStrategy: XNZCacheKeyStrategy.urlAndHeaders`。
2. 业务初始化阶段注册 `XNZImageMemoryObserver().init()`，在内存压力时及时清空内存缓存。
3. 动图场景较多时，按业务规模调优 `XNZAnimatedImage.cache` 的 `maxEntries`。
4. 如果需要跨格式统一样式包裹，优先使用 `renderBuilder`。
