# xnz_net_cache_image

Flutter 组件模版工程，包含：

- 组件库代码（`lib/`）
- 组件测试（`test/`）
- 可直接运行的 Demo（`example/`）

## 组件示例

```dart
XnzNetCacheImage(
  imageUrl: 'https://picsum.photos/800/480',
  width: 300,
  height: 180,
  borderRadius: BorderRadius.circular(12),
)
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

