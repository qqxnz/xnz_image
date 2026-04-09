# xnz_image 使用方式（核心 + 扩展）

## 1. 仅基础能力（不启用扩展）

```dart
import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';

void main() {
  runApp(const MyApp());
}
```

```dart
XNZNetworkImage(imageUrl: 'https://example.com/a.png');
XNZAssetImage(assetName: 'assets/a.png');
XNZFileImage(file: file);
XNZMemoryImage(bytes: bytes);
```

## 2. 启用 SVG 扩展

```dart
import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImage.support(XNZImageSvg());
  runApp(const MyApp());
}
```

## 3. 启用 AVIF 扩展

```dart
import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImage.support(XNZImageAvif());
  runApp(const MyApp());
}
```

## 4. 同时启用 SVG + AVIF

```dart
import 'package:flutter/material.dart';
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

## 5. 统一特殊渲染回调（新）

```dart
XNZNetworkImage(
  imageUrl: url,
  renderBuilder: (context, resolved) {
    if (resolved.kind == XNZResolvedKind.customWidget) {
      return resolved.widget!;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image(image: resolved.provider!, fit: BoxFit.cover),
    );
  },
);
```

## 6. 兼容旧参数（迁移期）

- `imageBuilder` / `svgBuilder` 保留并标记 `@Deprecated`。
- 新代码建议统一使用 `renderBuilder`。
