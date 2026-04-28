# xnz_image_svg

SVG support extension for `xnz_image`.

## Installation

```yaml
dependencies:
  xnz_image: ^0.1.10
  xnz_image_svg: ^0.1.10
```

## Usage

```dart
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';

void setupSvgSupport() {
  XNZImage.support(XNZImageSvg());
}
```
