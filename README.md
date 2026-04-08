# xnz_net_cache_image

Flutter 组件模版工程，包含：

- 组件库代码（`lib/`）
- 组件测试（`test/`）
- 可直接运行的 Demo（`example/`）

## 组件示例

```dart
XNZNetworkImage(
  url: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  fit: BoxFit.cover,
)
```

增强用法（圆角 + 进度 + 失败态）：

```dart
XNZNetworkImage(
  url: 'https://picsum.photos/800/480',
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

## 支持图片格式

- `avif`、`avifs`：组件内置 AVIF 解码路径（含动图时长控制能力）。
- 其他常见格式：`png`、`jpg`、`jpeg`、`gif`、`webp`、`bmp` 等，走 Flutter 原生 `ImageCodec` 解码（具体以目标平台解码能力为准）。

## 平台支持

- 当前组件不支持 Web 平台。
- 在 Web 端使用 `XNZNetworkImage` / `XNZMemoryAvifImage` 会返回不支持错误（`UnsupportedError`）。

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
