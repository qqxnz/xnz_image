# xnz_image_avif

AVIF support extension for `xnz_image`.

## Installation

```yaml
dependencies:
  xnz_image: ^0.1.4
  xnz_image_avif: ^0.1.4
```

## Usage

```dart
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';

void setupAvifSupport() {
  XNZImage.support(XNZImageAvif());
}
```
