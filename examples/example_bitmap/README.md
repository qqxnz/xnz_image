# xnz_image example

该目录是 `xnz_image` 的演示工程，用于快速验证以下能力：

- `XNZNetworkImage` 网络图片加载与缓存
- `XNZMemoryImage` 内存字节流渲染
- `XNZFileImage` 文件渲染
- `Image + *Provider` 组合接入方式
- `loadFailedBuilder` 失败回调示例

## 运行

```bash
# 在仓库根目录执行
fvm flutter pub get

# 进入 example
cd example
fvm flutter pub get
fvm flutter run
```

如果你没有使用 FVM，可将命令中的 `fvm flutter` 替换为 `flutter`。
